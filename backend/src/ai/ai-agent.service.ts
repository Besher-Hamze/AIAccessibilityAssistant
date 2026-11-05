import { Injectable, Logger } from '@nestjs/common';
import { Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { OllamaMessage, OllamaService } from './ollama.service';
import { AiToolsService } from './ai-tools.service';
import {
  formatToolReply,
  matchIntent,
  matchLooseListIntent,
} from './intent-router';

export interface ChatResult {
  reply: string;
  toolUsed?: string;
  toolResult?: unknown;
  intent?: 'ollama' | 'direct' | 'loose';
  speak: boolean;
}

@Injectable()
export class AiAgentService {
  private readonly logger = new Logger(AiAgentService.name);

  constructor(
    private ollama: OllamaService,
    private tools: AiToolsService,
    private prisma: PrismaService,
  ) {}

  async processMessage(
    userId: string,
    message: string,
    userRole: Role,
    speak = true,
    model?: string,
    signal?: AbortSignal,
  ): Promise<ChatResult> {
    const userMessage = await this.prisma.chatMessage.create({
      data: { userId, role: 'user', content: message },
    });

    const history = await this.prisma.chatMessage.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 10,
    });

    const messages = history
      .reverse()
      .slice(0, -1)
      .filter(
        (m) =>
          m.role !== 'assistant' ||
          !/لم أفهم|لم افهم|أعد صياغة|اعد صياغة/.test(m.content),
      )
      .map((m) => ({
        role: m.role as 'user' | 'assistant',
        content: m.content,
      }));

    messages.push({ role: 'user', content: message });

    let response: OllamaMessage;
    let modelFailed = false;
    try {
      response = await this.ollama.chat(messages, model, signal);
    } catch (err) {
      if (signal?.aborted) {
        // Cancelled by the user: do nothing, and keep it out of the history.
        await this.prisma.chatMessage.delete({ where: { id: userMessage.id } });
        return { reply: '', speak: false };
      }
      // Model down or too slow: the keyword matchers below can still answer.
      this.logger.warn(`Ollama failed: ${err}`);
      modelFailed = true;
      response = { role: 'assistant', content: '' };
    }

    if (response.tool_calls?.length) {
      const call = response.tool_calls[0];
      const toolName = call.function.name;
      const args = parseToolArgs(call.function.arguments);

      this.logger.log(
        `Ollama chose tool: ${toolName} (model=${model ?? 'default'})`,
      );
      try {
        const toolResult = await this.tools.execute(toolName, args, userRole);

        await this.tools.logAudit(userId, toolName, 'ai_command', undefined, {
          args,
          model: model ?? null,
          resultPreview: Array.isArray(toolResult)
            ? `${toolResult.length} records`
            : 'object',
        });

        const formatted = formatToolReply(toolName, toolResult, args);
        const reply =
          formatted !== 'تم تنفيذ الطلب.'
            ? formatted
            : await this.ollama.generateFinalReply(
                message,
                toolName,
                toolResult,
                model,
              );

        await this.prisma.chatMessage.create({
          data: {
            userId,
            role: 'assistant',
            content: reply,
            metadata: JSON.parse(
              JSON.stringify({
                toolUsed: toolName,
                toolResult,
                intent: 'ollama',
              }),
            ),
          },
        });

        return {
          reply,
          toolUsed: toolName,
          toolResult,
          intent: 'ollama',
          speak,
        };
      } catch (err) {
        this.logger.warn(`Ollama tool ${toolName} failed: ${err}`);
        // A real reason ("not enough stock") helps more than a retry that could
        // run a different, wrong action.
        const reason = errorMessage(err);
        const reply = `تعذّر تنفيذ الطلب: ${reason}`;
        await this.prisma.chatMessage.create({
          data: { userId, role: 'assistant', content: reply },
        });
        return { reply, toolUsed: toolName, intent: 'ollama', speak };
      }
    }

    const direct = matchIntent(message);
    if (direct) {
      try {
        this.logger.log(`Fallback intent: ${direct.tool}`);
        const toolResult = await this.tools.execute(
          direct.tool,
          direct.args,
          userRole,
        );
        await this.tools.logAudit(userId, direct.tool, 'voice_intent', undefined, {
          args: direct.args,
        });
        const reply = formatToolReply(direct.tool, toolResult, direct.args);
        await this.prisma.chatMessage.create({
          data: {
            userId,
            role: 'assistant',
            content: reply,
            metadata: JSON.parse(
              JSON.stringify({
                toolUsed: direct.tool,
                toolResult,
                intent: 'direct',
              }),
            ),
          },
        });
        return {
          reply,
          toolUsed: direct.tool,
          toolResult,
          intent: 'direct',
          speak,
        };
      } catch (err) {
        this.logger.warn(`Direct intent failed: ${err}`);
      }
    }

    const loose = matchLooseListIntent(message);
    if (loose) {
      try {
        this.logger.log(`Loose intent after LLM: ${loose.tool}`);
        const toolResult = await this.tools.execute(
          loose.tool,
          loose.args,
          userRole,
        );
        await this.tools.logAudit(userId, loose.tool, 'voice_intent', undefined, {
          args: loose.args,
          fallback: 'loose',
        });
        const reply = formatToolReply(loose.tool, toolResult, loose.args);
        await this.prisma.chatMessage.create({
          data: {
            userId,
            role: 'assistant',
            content: reply,
            metadata: JSON.parse(
              JSON.stringify({
                toolUsed: loose.tool,
                toolResult,
                intent: 'loose',
              }),
            ),
          },
        });
        return {
          reply,
          toolUsed: loose.tool,
          toolResult,
          intent: 'loose',
          speak,
        };
      } catch (err) {
        this.logger.warn(`Loose intent failed: ${err}`);
      }
    }

    const modelText = response.content?.trim();
    const reply =
      (modelText && !NOT_ARABIC_SCRIPT.test(modelText) ? modelText : '') ||
      (modelFailed
        ? 'لا أستطيع الوصول إلى نموذج الذكاء حالياً. يمكنك استخدام أوامر التنقل مثل: افتح العملاء.'
        : 'عذراً، لم أفهم طلبك. هل يمكنك إعادة صياغته؟');

    await this.prisma.chatMessage.create({
      data: { userId, role: 'assistant', content: reply },
    });

    return { reply, speak };
  }

  async clearHistory(userId: string) {
    const result = await this.prisma.chatMessage.deleteMany({
      where: { userId },
    });
    return { ok: true, deleted: result.count };
  }

  getHistory(userId: string) {
    return this.prisma.chatMessage.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
      take: 100,
      select: {
        id: true,
        role: true,
        content: true,
        metadata: true,
        createdAt: true,
      },
    });
  }
}

/** Small models sometimes drift into Chinese or Russian, which the Arabic voice cannot read. */
const NOT_ARABIC_SCRIPT = /[\u0400-\u04ff\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]/;

function errorMessage(err: unknown): string {
  const response = (err as { response?: { message?: unknown } }).response;
  if (typeof response?.message === 'string') return response.message;
  return err instanceof Error ? err.message : 'خطأ غير معروف';
}

function parseToolArgs(raw: unknown): Record<string, unknown> {
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
