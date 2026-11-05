import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { InvoiceStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCustomerDto, UpdateCustomerDto } from './dto/customer.dto';

@Injectable()
export class CustomersService {
  constructor(private prisma: PrismaService) {}

  findAll(search?: string) {
    return this.prisma.customer.findMany({
      where: search
        ? {
            OR: [
              { name: { contains: search, mode: 'insensitive' } },
              { phone: { contains: search, mode: 'insensitive' } },
              { email: { contains: search, mode: 'insensitive' } },
            ],
          }
        : undefined,
      orderBy: { name: 'asc' },
      include: {
        _count: { select: { invoices: true } },
      },
    });
  }

  async findOne(id: string) {
    const customer = await this.prisma.customer.findUnique({
      where: { id },
      include: {
        invoices: {
          orderBy: { date: 'desc' },
          take: 10,
        },
      },
    });
    if (!customer) throw new NotFoundException('العميل غير موجود');
    return customer;
  }

  /**
   * Everything about one customer: all invoices with their items, plus totals.
   * Totals count paid and pending invoices; drafts and cancelled ones are listed
   * but are not money owed or earned.
   */
  async getAccount(id: string) {
    const customer = await this.prisma.customer.findUnique({
      where: { id },
      include: {
        invoices: {
          orderBy: { date: 'desc' },
          include: {
            items: { include: { product: { select: { id: true, name: true } } } },
          },
        },
      },
    });
    if (!customer) throw new NotFoundException('العميل غير موجود');

    const zero = new Prisma.Decimal(0);
    let paid = zero;
    let pending = zero;
    let units = 0;
    const products = new Map<
      string,
      {
        productId: string;
        name: string;
        quantity: number;
        amount: Prisma.Decimal;
        lastDate: Date;
      }
    >();
    const counts = { PAID: 0, PENDING: 0, DRAFT: 0, CANCELLED: 0 };

    for (const invoice of customer.invoices) {
      counts[invoice.status]++;
      if (invoice.status === InvoiceStatus.PAID) paid = paid.add(invoice.total);
      if (invoice.status === InvoiceStatus.PENDING) {
        pending = pending.add(invoice.total);
      }
      if (
        invoice.status !== InvoiceStatus.PAID &&
        invoice.status !== InvoiceStatus.PENDING
      ) {
        continue;
      }
      for (const item of invoice.items) {
        units += item.quantity;
        const row = products.get(item.productId) ?? {
          productId: item.productId,
          name: item.product.name,
          quantity: 0,
          amount: zero,
          lastDate: invoice.date,
        };
        row.quantity += item.quantity;
        row.amount = row.amount.add(item.subtotal);
        if (invoice.date > row.lastDate) row.lastDate = invoice.date;
        products.set(item.productId, row);
      }
    }

    return {
      customer: {
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        email: customer.email,
        address: customer.address,
      },
      invoices: customer.invoices.map((inv) => ({
        ...inv,
        customer: { id: customer.id, name: customer.name },
      })),
      products: [...products.values()].sort((a, b) => b.quantity - a.quantity),
      stats: {
        invoiceCount: customer.invoices.length,
        counts,
        totalAmount: paid.add(pending),
        paidAmount: paid,
        pendingAmount: pending,
        totalUnits: units,
      },
    };
  }

  async getAccountByName(name: string) {
    const found = await this.prisma.customer.findFirst({
      where: { name: { contains: name, mode: 'insensitive' } },
    });
    if (!found) throw new NotFoundException(`العميل غير موجود: ${name}`);
    return this.getAccount(found.id);
  }

  create(dto: CreateCustomerDto) {
    return this.prisma.customer.create({ data: dto });
  }

  async update(id: string, dto: UpdateCustomerDto, isAdmin: boolean) {
    if (!isAdmin) {
      throw new ForbiddenException('ليس لديك صلاحية التعديل');
    }
    await this.findOne(id);
    return this.prisma.customer.update({ where: { id }, data: dto });
  }

  async remove(id: string, isAdmin: boolean) {
    if (!isAdmin) {
      throw new ForbiddenException('ليس لديك صلاحية الحذف');
    }
    await this.findOne(id);
    return this.prisma.customer.delete({ where: { id } });
  }
}
