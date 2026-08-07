import { Module } from '@nestjs/common';
import { AiAgentService } from './ai-agent.service';
import { AiToolsService } from './ai-tools.service';
import { OllamaService } from './ollama.service';
import { AiController } from './ai.controller';
import { CustomersModule } from '../customers/customers.module';
import { ProductsModule } from '../products/products.module';
import { InvoicesModule } from '../invoices/invoices.module';

@Module({
  imports: [CustomersModule, ProductsModule, InvoicesModule],
  controllers: [AiController],
  providers: [AiAgentService, AiToolsService, OllamaService],
  exports: [AiAgentService],
})
export class AiModule {}
