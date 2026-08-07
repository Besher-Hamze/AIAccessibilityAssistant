import { Injectable, Logger } from '@nestjs/common';
import { Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { OllamaService } from './ollama.service';
import { AiToolsService } from './ai-tools.service';

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

    const response = await this.ollama.chat(messages);

    if (response.tool_calls?.length) {
      const call = response.tool_calls[0];
      const toolName = call.function.name;
      const args =
        typeof call.function.arguments === 'string'
          ? JSON.parse(call.function.arguments)
          : call.function.arguments;

      this.logger.log(`Executing tool: ${toolName}`);
      const toolResult = await this.tools.execute(toolName, args, userRole);

      await this.tools.logAudit(userId, toolName, 'ai_command', undefined, {
        args,
        resultPreview: Array.isArray(toolResult)
          ? `${toolResult.length} records`
          : 'object',
      });

      const reply = await this.ollama.generateFinalReply(
        message,
        toolName,
        toolResult,
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
