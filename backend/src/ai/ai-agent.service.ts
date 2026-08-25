import { Injectable, Logger } from '@nestjs/common';
import { Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { OllamaService } from './ollama.service';
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
  ): Promise<ChatResult> {
    await this.prisma.chatMessage.create({
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
      .map((m) => ({
        role: m.role as 'user' | 'assistant',
        content: m.content,
      }));

    messages.push({ role: 'user', content: message });

    const direct = matchIntent(message);
    if (direct) {
      try {
        this.logger.log(`Direct intent: ${direct.tool}`);
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
        return { reply, toolUsed: direct.tool, toolResult, speak };
      } catch (err) {
        this.logger.warn(`Direct intent failed, falling back to LLM: ${err}`);
      }
    }

    const response = await this.ollama.chat(messages, model);

    if (response.tool_calls?.length) {
      const call = response.tool_calls[0];
      const toolName = call.function.name;
      const args =
        typeof call.function.arguments === 'string'
          ? JSON.parse(call.function.arguments)
          : call.function.arguments;

      this.logger.log(`Executing tool: ${toolName} (model=${model ?? 'default'})`);
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
            JSON.stringify({ toolUsed: toolName, toolResult }),
          ),
        },
      });

      return { reply, toolUsed: toolName, toolResult, speak };
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
        return { reply, toolUsed: loose.tool, toolResult, speak };
      } catch (err) {
        this.logger.warn(`Loose intent failed: ${err}`);
      }
    }

    const reply =
      response.content?.trim() ||
      'عذراً، لم أفهم طلبك. هل يمكنك إعادة صياغته؟';

    await this.prisma.chatMessage.create({
      data: { userId, role: 'assistant', content: reply },
    });

    return { reply, speak };
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
