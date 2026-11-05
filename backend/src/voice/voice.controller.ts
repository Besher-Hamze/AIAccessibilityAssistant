import {
  Controller,
  Post,
  Get,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  Body,
  Res,
  StreamableFile,
  Delete,
  Request,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import type { Response } from 'express';
import { IsOptional, IsString } from 'class-validator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

class TtsDto {
  @IsString()
  text: string;

  @IsOptional()
  @IsString()
  voice?: string;
}

@Controller('voice')
@UseGuards(JwtAuthGuard)
export class VoiceController {
  private readonly aiServiceUrl: string;

  constructor(config: ConfigService) {
    this.aiServiceUrl = config.get('AI_SERVICE_URL', 'http://localhost:8000');
  }

  @Post('speech-to-text')
  @UseInterceptors(FileInterceptor('audio'))
  async speechToText(
    @UploadedFile() file: Express.Multer.File,
    @Request() req: { user: { id: string } },
  ) {
    if (!file) {
      return { text: '', error: 'لم يتم إرسال ملف صوتي' };
    }

    const formData = this.audioForm(file, req.user.id);

    const { data } = await axios.post(
      `${this.aiServiceUrl}/stt`,
      formData,
      { timeout: 120000 },
    );

    return data;
  }

  /** Saves the signed-in user's voiceprint so only their voice is transcribed. */
  @Post('voiceprint')
  @UseInterceptors(FileInterceptor('audio'))
  async enrollVoiceprint(
    @UploadedFile() file: Express.Multer.File,
    @Request() req: { user: { id: string } },
  ) {
    if (!file) return { ok: false, error: 'لم يتم إرسال ملف صوتي' };
    const { data } = await axios.post(
      `${this.aiServiceUrl}/voiceprint`,
      this.audioForm(file, req.user.id),
      { timeout: 60000 },
    );
    return data;
  }

  @Get('voiceprint')
  async voiceprintStatus(@Request() req: { user: { id: string } }) {
    const { data } = await axios.get(
      `${this.aiServiceUrl}/voiceprint/${req.user.id}`,
      { timeout: 10000 },
    );
    return data;
  }

  @Delete('voiceprint')
  async deleteVoiceprint(@Request() req: { user: { id: string } }) {
    const { data } = await axios.delete(
      `${this.aiServiceUrl}/voiceprint/${req.user.id}`,
      { timeout: 10000 },
    );
    return data;
  }

  private audioForm(file: Express.Multer.File, speakerId: string) {
    const formData = new FormData();
    const blob = new Blob([new Uint8Array(file.buffer)], {
      type: file.mimetype,
    });
    formData.append('file', blob, file.originalname || 'audio.wav');
    formData.append('speaker_id', speakerId);
    return formData;
  }

  @Post('text-to-speech')
  async textToSpeech(@Body() dto: TtsDto, @Res({ passthrough: true }) res: Response) {
    const { data, headers } = await axios.post(
      `${this.aiServiceUrl}/tts`,
      { text: dto.text, voice: dto.voice },
      { responseType: 'arraybuffer', timeout: 60000 },
    );

    res.set({
      'Content-Type': headers['content-type'] ?? 'audio/mpeg',
      'Content-Disposition': 'inline; filename="speech.mp3"',
    });

    return new StreamableFile(Buffer.from(data));
  }

  @Get('health')
  async health() {
    try {
      const { data } = await axios.get(`${this.aiServiceUrl}/health`, {
        timeout: 5000,
      });
      return data;
    } catch {
      return { ok: false, error: 'AI voice service unavailable' };
    }
  }
}
