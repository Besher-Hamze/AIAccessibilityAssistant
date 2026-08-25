import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import { AI_TOOLS } from './ai.constants';
import {
  TOOL_NAMES,
  buildFinalReplyPrompt,
  buildJsonFallbackPrompt,
  buildSystemPrompt,
} from './prompt-builder';

export interface OllamaMessage {
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

  async chat(messages: OllamaMessage[], model?: string): Promise<OllamaMessage> {
    const selectedModel = this.resolveModel(model);
    const today = new Date().toISOString().split('T')[0];
    const systemPrompt = buildSystemPrompt(today);

    const payload = {
      model: selectedModel,
      messages: [{ role: 'system', content: systemPrompt }, ...messages],
      tools: AI_TOOLS,
      stream: false,
      options: { temperature: 0 },
    };

    try {
      const { data } = await axios.post(
        `${this.baseUrl}/api/chat`,
        payload,
        { timeout: 180000 },
      );
      const normalized = normalizeOllamaMessage(data.message);
      if (normalized.tool_calls?.length) {
        this.logger.log(
          `Tool from native API: ${normalized.tool_calls[0].function.name}`,
        );
        return normalized;
      }

      const fromText = extractToolFromContent(normalized.content);
      if (fromText?.tool_calls?.length) {
        this.logger.log(
          `Tool from model text: ${fromText.tool_calls[0].function.name}`,
        );
        return fromText;
      }

      if (looksUnhelpful(normalized.content)) {
        this.logger.warn(
          `No tool from ${selectedModel}, using JSON function-pick fallback`,
        );
        return this.chatJsonFallback(messages, selectedModel);
      }

      return normalized;
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
  ): Promise<OllamaMessage> {
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
        options: { temperature: 0 },
      },
      { timeout: 180000 },
    );

    const content = data.message?.content ?? '{}';
    const fromText = extractToolFromContent(content);
    if (fromText?.tool_calls?.length) {
      this.logger.log(
        `Tool from JSON mode: ${fromText.tool_calls[0].function.name}`,
      );
      return fromText;
    }

    try {
      const parsed = JSON.parse(content) as {
        tool: string | null;
        arguments?: Record<string, unknown>;
        reply?: string;
      };

      if (parsed.tool && TOOL_NAMES.includes(parsed.tool)) {
        return toToolMessage(parsed.tool, parsed.arguments ?? {});
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

function toToolMessage(
  name: string,
  args: Record<string, unknown>,
): OllamaMessage {
  return {
    role: 'assistant',
    content: '',
    tool_calls: [{ function: { name, arguments: args } }],
  };
}

function parseArgs(raw: unknown): Record<string, unknown> {
  if (raw && typeof raw === 'object' && !Array.isArray(raw)) {
    return raw as Record<string, unknown>;
  }
  if (typeof raw === 'string' && raw.trim()) {
    try {
      const parsed = JSON.parse(raw) as unknown;
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed as Record<string, unknown>;
      }
    } catch {
      return {};
    }
  }
  return {};
}

function normalizeOllamaMessage(raw: unknown): OllamaMessage {
  const msg = (raw ?? {}) as {
    role?: string;
    content?: string;
    tool_calls?: Array<{
      function?: { name?: string; arguments?: unknown };
      name?: string;
      arguments?: unknown;
    }>;
  };

  const toolCalls = (msg.tool_calls ?? [])
    .map((call) => {
      const name = call.function?.name ?? call.name;
      if (!name || !TOOL_NAMES.includes(name)) return null;
      return {
        function: {
          name,
          arguments: parseArgs(call.function?.arguments ?? call.arguments),
        },
      };
    })
    .filter((c): c is NonNullable<typeof c> => c !== null);

  return {
    role: 'assistant',
    content: msg.content ?? '',
    ...(toolCalls.length ? { tool_calls: toolCalls } : {}),
  };
}

function extractToolFromContent(content?: string): OllamaMessage | null {
  if (!content) return null;
  const text = content.trim();
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const chunks = [fenced?.[1], text].filter(Boolean) as string[];

  const tag = text.match(/<tool_call>\s*([\s\S]*?)<\/tool_call>/i);
  if (tag) chunks.unshift(tag[1]);

  for (const chunk of chunks) {
    const jsonMatch = chunk.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      const lone = chunk.trim();
      if (TOOL_NAMES.includes(lone)) return toToolMessage(lone, {});
      continue;
    }
    try {
      const parsed = JSON.parse(jsonMatch[0]) as Record<string, unknown>;
      const name = String(
        parsed.tool ?? parsed.name ?? (parsed.function as string | undefined) ?? '',
      );
      const args = parseArgs(
        parsed.arguments ?? parsed.args ?? parsed.parameters,
      );
      if (TOOL_NAMES.includes(name)) return toToolMessage(name, args);
    } catch {
      continue;
    }
  }

  return null;
}

function looksUnhelpful(content?: string): boolean {
  const c = (content ?? '').trim();
  if (!c) return true;
  return /لم أفهم|لم افهم|أعد صياغة|اعد صياغة|غير واضح|وضح طلبك|ما المقصود|لا أستطيع فهم/.test(
    c,
  );
}
