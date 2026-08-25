import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  UseGuards,
  Request,
} from '@nestjs/common';
import { IsBoolean, IsOptional, IsString, MinLength } from 'class-validator';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AiAgentService } from './ai-agent.service';
import { OllamaService } from './ollama.service';

class ChatDto {
  @IsString()
  @MinLength(1)
  message: string;

  @IsOptional()
  @IsBoolean()
  speak?: boolean;

  @IsOptional()
  @IsString()
  model?: string;
}

@Controller('ai')
@UseGuards(JwtAuthGuard)
export class AiController {
  constructor(
    private aiAgent: AiAgentService,
    private ollama: OllamaService,
  ) {}

  @Post('chat')
  async chat(
    @Body() dto: ChatDto,
    @Request() req: { user: { id: string; role: Role } },
  ) {
    return this.aiAgent.processMessage(
      req.user.id,
      dto.message,
      req.user.role,
      dto.speak ?? true,
      dto.model,
    );
  }

  @Get('history')
  getHistory(@Request() req: { user: { id: string } }) {
    return this.aiAgent.getHistory(req.user.id);
  }

  @Delete('history')
  clearHistory(@Request() req: { user: { id: string } }) {
    return this.aiAgent.clearHistory(req.user.id);
  }

  @Get('models')
  async models() {
    return this.ollama.listModels();
  }

  @Get('health')
  async health() {
    return this.ollama.checkHealth();
  }
}
