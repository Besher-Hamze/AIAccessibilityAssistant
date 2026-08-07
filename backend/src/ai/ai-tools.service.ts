import {
  Injectable,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InvoiceStatus, Role } from '@prisma/client';
import { CustomersService } from '../customers/customers.service';
import { ProductsService } from '../products/products.service';
import { InvoicesService } from '../invoices/invoices.service';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AiToolsService {
  constructor(
    private customers: CustomersService,
    private products: ProductsService,
    private invoices: InvoicesService,
    private prisma: PrismaService,
  ) {}

  async execute(
    toolName: string,
    args: Record<string, unknown>,
    userRole: Role,
  ): Promise<unknown> {
    const isAdmin = userRole === Role.ADMIN;

    switch (toolName) {
      case 'search_customers':
        return this.customers.findAll(String(args.query ?? ''));

      case 'create_customer':
        this.assertCanWrite(userRole);
        return this.customers.create({
          name: String(args.name),
          phone: args.phone ? String(args.phone) : undefined,
          email: args.email ? String(args.email) : undefined,
          address: args.address ? String(args.address) : undefined,
        });

      case 'update_customer': {
        this.assertAdmin(userRole);
        const found = await this.prisma.customer.findFirst({
          where: {
            name: {
              contains: String(args.customerName ?? ''),
              mode: 'insensitive',
            },
          },
        });
        if (!found) throw new BadRequestException('العميل غير موجود');
        return this.customers.update(
          found.id,
          {
            name: args.name ? String(args.name) : undefined,
            phone: args.phone ? String(args.phone) : undefined,
            email: args.email ? String(args.email) : undefined,
            address: args.address ? String(args.address) : undefined,
          },
          true,
        );
      }

      case 'list_products':
        return this.products.findAll(
          args.search ? String(args.search) : undefined,
        );

      case 'create_product':
        this.assertAdmin(userRole);
        return this.products.create({
          name: String(args.name),
          description: args.description
            ? String(args.description)
            : undefined,
          price: Number(args.price),
          stock: args.stock !== undefined ? Number(args.stock) : 0,
        });

      case 'update_product_stock': {
        this.assertAdmin(userRole);
        const product = await this.prisma.product.findFirst({
          where: {
            name: {
              contains: String(args.productName ?? ''),
              mode: 'insensitive',
            },
          },
        });
        if (!product) throw new BadRequestException('المنتج غير موجود');
        return this.products.update(
          product.id,
          {
            stock:
              args.stock !== undefined ? Number(args.stock) : undefined,
            price:
              args.price !== undefined ? Number(args.price) : undefined,
          },
          true,
        );
      }

      case 'get_customer_invoices':
        return this.invoices.findAll({
          customerName: String(args.customerName ?? ''),
          status: args.status as InvoiceStatus | undefined,
          fromDate: args.fromDate
            ? new Date(String(args.fromDate))
            : undefined,
          toDate: args.toDate ? new Date(String(args.toDate)) : undefined,
        });

      case 'get_latest_invoice':
        return this.invoices.findAll({
          customerName: args.customerName
            ? String(args.customerName)
            : undefined,
          latest: true,
        });

      case 'search_invoices':
        return this.invoices.findAll({
          customerName: args.customerName
            ? String(args.customerName)
            : undefined,
          status: args.status as InvoiceStatus | undefined,
          fromDate: args.fromDate
            ? new Date(String(args.fromDate))
            : undefined,
          toDate: args.toDate ? new Date(String(args.toDate)) : undefined,
        });

      case 'create_invoice': {
        this.assertCanWrite(userRole);
        const items = (args.items as Array<{
          productName: string;
          quantity: number;
        }>) ?? [];
        if (!items.length) {
          throw new BadRequestException('يجب تحديد بنود الفاتورة');
        }
        return this.invoices.createByNames(
          String(args.customerName),
          items,
          args.notes ? String(args.notes) : undefined,
          args.status as InvoiceStatus | undefined,
        );
      }

      case 'update_invoice_status':
        this.assertAdmin(userRole);
        return this.invoices.updateStatusByNumber(
          String(args.invoiceNumber),
          args.status as InvoiceStatus,
          isAdmin,
        );

      case 'get_accounting_summary':
        return this.invoices.getSummary(
          args.fromDate ? new Date(String(args.fromDate)) : undefined,
          args.toDate ? new Date(String(args.toDate)) : undefined,
        );

      case 'generate_report':
        return this.invoices.generateReport({
          customerName: args.customerName
            ? String(args.customerName)
            : undefined,
          status: args.status as InvoiceStatus | undefined,
          fromDate: args.fromDate
            ? new Date(String(args.fromDate))
            : undefined,
          toDate: args.toDate ? new Date(String(args.toDate)) : undefined,
        });

      default:
        return { error: `أداة غير معروفة: ${toolName}` };
    }
  }

  async logAudit(
    userId: string,
    action: string,
    entity: string,
    entityId?: string,
    details?: unknown,
  ) {
    await this.prisma.auditLog.create({
      data: {
        userId,
        action,
        entity,
        entityId,
        details: details ? (details as object) : undefined,
      },
    });
  }

  assertCanWrite(role: Role) {
    if (role === Role.USER || role === Role.ADMIN) return;
    throw new ForbiddenException('ليس لديك صلاحية');
  }

  assertAdmin(role: Role) {
    if (role !== Role.ADMIN) {
      throw new ForbiddenException('هذه العملية للمدير فقط');
    }
  }

  /** @deprecated use assertCanWrite */
  assertCanCreate(role: Role) {
    this.assertCanWrite(role);
  }
}
