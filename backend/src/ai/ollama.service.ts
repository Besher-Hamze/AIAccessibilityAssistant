import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import { AI_TOOLS } from './ai.constants';
import {
  buildFinalReplyPrompt,
  buildJsonFallbackPrompt,
  buildSystemPrompt,
} from './prompt-builder';

interface OllamaMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
  tool_calls?: Array<{
    function: { name: string; arguments: Record<string, unknown> };
  }>;
}

@Injectable()
export class OllamaService {
  private readonly logger = new Logger(OllamaService.name);
  private readonly baseUrl: string;
  private readonly defaultModel: string;

  constructor(private config: ConfigService) {
    this.baseUrl = config.get('OLLAMA_BASE_URL', 'http://localhost:11434');
    this.defaultModel = config.get('OLLAMA_MODEL', 'qwen2.5:3b');
  }

  resolveModel(model?: string) {
    const value = model?.trim();
    return value && value.length > 0 ? value : this.defaultModel;
  }

  async listModels(): Promise<{
    ok: boolean;
    models: string[];
    current: string;
  }> {
    try {
      const { data } = await axios.get(`${this.baseUrl}/api/tags`, {
        timeout: 5000,
      });
      const models = ((data.models as Array<{ name?: string }> | undefined) ?? [])
        .map((m) => m.name)
        .filter((name): name is string => !!name)
        .sort((a, b) => a.localeCompare(b));
      return { ok: true, models, current: this.defaultModel };
    } catch {
      return { ok: false, models: [], current: this.defaultModel };
    }
  }

  async chat(messages: OllamaMessage[], model?: string) {
    const selectedModel = this.resolveModel(model);
    const today = new Date().toISOString().split('T')[0];
    const systemPrompt = buildSystemPrompt(today);

    const payload = {
      model: selectedModel,
      messages: [{ role: 'system', content: systemPrompt }, ...messages],
      tools: AI_TOOLS,
      stream: false,
      options: { temperature: 0.1 },
    };

    try {
      const { data } = await axios.post(
        `${this.baseUrl}/api/chat`,
        payload,
        { timeout: 180000 },
      );
      return data.message as OllamaMessage;
    } catch (error) {
      this.logger.warn(
        `Ollama tools API failed for ${selectedModel}, trying JSON mode`,
      );
      return this.chatJsonFallback(messages, selectedModel);
    }
  }

  private async chatJsonFallback(
    messages: OllamaMessage[],
    selectedModel: string,
  ) {
    const jsonPrompt = buildJsonFallbackPrompt(
      new Date().toISOString().split('T')[0],
    );

    const { data } = await axios.post(
      `${this.baseUrl}/api/chat`,
      {
        model: selectedModel,
        messages: [{ role: 'system', content: jsonPrompt }, ...messages],
        stream: false,
        format: 'json',
        options: { temperature: 0.1 },
      },
      { timeout: 180000 },
    );

    const content = data.message?.content ?? '{}';
    try {
      const parsed = JSON.parse(content) as {
        tool: string | null;
        arguments?: Record<string, unknown>;
        reply?: string;
      };

      if (parsed.tool) {
        return {
          role: 'assistant' as const,
          content: '',
          tool_calls: [
            {
              function: {
                name: parsed.tool,
                arguments: parsed.arguments ?? {},
              },
            },
          ],
        };
      }

      return {
        role: 'assistant' as const,
        content: parsed.reply ?? 'تم.',
      };
    } catch {
      return {
        role: 'assistant' as const,
        content: content,
      };
    }
  }

  async generateFinalReply(
    userMessage: string,
    toolName: string,
    toolResult: unknown,
    model?: string,
  ) {
    const selectedModel = this.resolveModel(model);
    const { data } = await axios.post(
      `${this.baseUrl}/api/chat`,
      {
        model: selectedModel,
        messages: [
          {
            role: 'system',
            content: buildFinalReplyPrompt(),
          },
          {
            role: 'user',
            content: `طلب المستخدم: ${userMessage}\n\nالعملية: ${toolName}\n\nالنتيجة:\n${JSON.stringify(toolResult, null, 2)}`,
          },
        ],
        stream: false,
        options: { temperature: 0.3 },
      },
      { timeout: 180000 },
    );

    return (data.message?.content as string) ?? 'تم تنفيذ العملية بنجاح.';
  }

  async checkHealth() {
    const listed = await this.listModels();
    return {
      ok: listed.ok,
      models: listed.models.map((name) => ({ name })),
      current: listed.current,
    };
  }
}
