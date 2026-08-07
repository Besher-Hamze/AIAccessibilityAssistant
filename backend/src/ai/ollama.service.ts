import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import { AI_TOOLS, SYSTEM_PROMPT } from './ai.constants';

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
  private readonly model: string;

  constructor(private config: ConfigService) {
    this.baseUrl = config.get('OLLAMA_BASE_URL', 'http://localhost:11434');
    this.model = config.get('OLLAMA_MODEL', 'qwen2.5:3b');
  }

  async chat(messages: OllamaMessage[]) {
    const systemPrompt = SYSTEM_PROMPT.replace(
      '{{TODAY}}',
      new Date().toISOString().split('T')[0],
    );

    const payload = {
      model: this.model,
      messages: [{ role: 'system', content: systemPrompt }, ...messages],
      tools: AI_TOOLS,
      stream: false,
      options: { temperature: 0.2 },
    };

    try {
      const { data } = await axios.post(
        `${this.baseUrl}/api/chat`,
        payload,
        { timeout: 120000 },
      );
      return data.message as OllamaMessage;
    } catch (error) {
      this.logger.warn('Ollama tools API failed, trying JSON mode');
      return this.chatJsonFallback(messages, systemPrompt);
    }
  }

  private async chatJsonFallback(
    messages: OllamaMessage[],
    systemPrompt: string,
  ) {
    const toolDesc = AI_TOOLS.map(
      (t) => `- ${t.function.name}: ${t.function.description}`,
    ).join('\n');

    const jsonPrompt = `${systemPrompt}

الأدوات المتاحة:
${toolDesc}

إذا احتجت تنفيذ عملية، أجب بـ JSON فقط بهذا الشكل:
{"tool": "اسم_الأداة", "arguments": {...}}

إذا كان رداً عادياً بدون عملية:
{"tool": null, "reply": "ردك بالعربية"}
`;

    const { data } = await axios.post(
      `${this.baseUrl}/api/chat`,
      {
        model: this.model,
        messages: [{ role: 'system', content: jsonPrompt }, ...messages],
        stream: false,
        format: 'json',
        options: { temperature: 0.2 },
      },
      { timeout: 120000 },
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
  ) {
    const { data } = await axios.post(
      `${this.baseUrl}/api/chat`,
      {
        model: this.model,
        messages: [
          {
            role: 'system',
            content:
              'لخّص نتيجة العملية للمستخدم بالعربية بشكل واضح ومختصر ومناسب للقراءة الصوتية. لا تستخدم JSON.',
          },
          {
            role: 'user',
            content: `طلب المستخدم: ${userMessage}\n\nالعملية: ${toolName}\n\nالنتيجة:\n${JSON.stringify(toolResult, null, 2)}`,
          },
        ],
        stream: false,
        options: { temperature: 0.3 },
      },
      { timeout: 120000 },
    );

    return (data.message?.content as string) ?? 'تم تنفيذ العملية بنجاح.';
  }

  async checkHealth() {
    try {
      const { data } = await axios.get(`${this.baseUrl}/api/tags`, {
        timeout: 5000,
      });
      return { ok: true, models: data.models ?? [] };
    } catch {
      return { ok: false, models: [] };
    }
  }
}
