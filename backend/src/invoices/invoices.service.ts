import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { Prisma, InvoiceStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateInvoiceDto } from './dto/invoice.dto';

export interface InvoiceSearchParams {
  customerName?: string;
  status?: InvoiceStatus;
  fromDate?: Date;
  toDate?: Date;
  latest?: boolean;
  limit?: number;
}

export interface CreateInvoiceByNameItem {
  productName: string;
  quantity: number;
}

@Injectable()
export class InvoicesService {
  constructor(private prisma: PrismaService) {}

  async findAll(params: InvoiceSearchParams = {}) {
    const where: Prisma.InvoiceWhereInput = {};

    if (params.customerName) {
      where.customer = {
        name: { contains: params.customerName, mode: 'insensitive' },
      };
    }
    if (params.status) where.status = params.status;
    if (params.fromDate || params.toDate) {
      where.date = {};
      if (params.fromDate) where.date.gte = params.fromDate;
      if (params.toDate) where.date.lte = params.toDate;
    }

    const take = params.latest ? 1 : params.limit ?? 50;

    return this.prisma.invoice.findMany({
      where,
      take,
      orderBy: { date: 'desc' },
      include: {
        customer: { select: { id: true, name: true, phone: true } },
        items: {
          include: { product: { select: { id: true, name: true } } },
        },
      },
    });
  }

  async findOne(id: string) {
    const invoice = await this.prisma.invoice.findUnique({
      where: { id },
      include: {
        customer: true,
        items: { include: { product: true } },
      },
    });
    if (!invoice) throw new NotFoundException('الفاتورة غير موجودة');
    return invoice;
  }

  async findByNumber(number: string) {
    const invoice = await this.prisma.invoice.findUnique({
      where: { number },
      include: {
        customer: true,
        items: { include: { product: true } },
      },
    });
    if (!invoice) throw new NotFoundException('الفاتورة غير موجودة');
    return invoice;
  }

  async create(dto: CreateInvoiceDto) {
    const customer = await this.prisma.customer.findUnique({
      where: { id: dto.customerId },
    });
    if (!customer) throw new BadRequestException('العميل غير موجود');

    const productIds = dto.items.map((i) => i.productId);
    const products = await this.prisma.product.findMany({
      where: { id: { in: productIds } },
    });
    if (products.length !== productIds.length) {
      throw new BadRequestException('أحد المنتجات غير موجود');
    }

    const productMap = new Map(products.map((p) => [p.id, p]));
    let total = new Prisma.Decimal(0);
    const itemsData = dto.items.map((item) => {
      const product = productMap.get(item.productId)!;
      if (item.quantity < 1) {
        throw new BadRequestException('الكمية يجب أن تكون 1 على الأقل');
      }
      if (product.stock < item.quantity) {
        throw new BadRequestException(
          `المخزون غير كافٍ للمنتج: ${product.name} (المتاح: ${product.stock})`,
        );
      }
      const unitPrice = product.price;
      const subtotal = unitPrice.mul(item.quantity);
      total = total.add(subtotal);
      return {
        productId: item.productId,
        quantity: item.quantity,
        unitPrice,
        subtotal,
      };
    });

    const count = await this.prisma.invoice.count();
    const number = `INV-${String(count + 1).padStart(5, '0')}`;

    return this.prisma.$transaction(async (tx) => {
      for (const item of itemsData) {
        await tx.product.update({
          where: { id: item.productId },
          data: { stock: { decrement: item.quantity } },
        });
      }

      return tx.invoice.create({
        data: {
          number,
          customerId: dto.customerId,
          total,
          status: dto.status ?? InvoiceStatus.PENDING,
          notes: dto.notes,
          items: { create: itemsData },
        },
        include: {
          customer: true,
          items: { include: { product: true } },
        },
      });
    });
  }

  async createByNames(
    customerName: string,
    items: CreateInvoiceByNameItem[],
    notes?: string,
    status?: InvoiceStatus,
  ) {
    const customer = await this.prisma.customer.findFirst({
      where: { name: { contains: customerName, mode: 'insensitive' } },
    });
    if (!customer) {
      throw new BadRequestException(`العميل غير موجود: ${customerName}`);
    }

    const resolvedItems: { productId: string; quantity: number }[] = [];
    for (const item of items) {
      const product = await this.prisma.product.findFirst({
        where: { name: { contains: item.productName, mode: 'insensitive' } },
      });
      if (!product) {
        throw new BadRequestException(`المنتج غير موجود: ${item.productName}`);
      }
      resolvedItems.push({
        productId: product.id,
        quantity: Number(item.quantity),
      });
    }

    return this.create({
      customerId: customer.id,
      items: resolvedItems,
      notes,
      status,
    });
  }

  async updateStatus(id: string, status: InvoiceStatus, isAdmin: boolean) {
    if (!isAdmin) throw new ForbiddenException('ليس لديك صلاحية التعديل');
    const invoice = await this.findOne(id);

    return this.prisma.$transaction(async (tx) => {
      if (
        invoice.status !== InvoiceStatus.CANCELLED &&
        status === InvoiceStatus.CANCELLED
      ) {
        for (const item of invoice.items) {
          await tx.product.update({
            where: { id: item.productId },
            data: { stock: { increment: item.quantity } },
          });
        }
      }

      if (
        invoice.status === InvoiceStatus.CANCELLED &&
        status !== InvoiceStatus.CANCELLED
      ) {
        for (const item of invoice.items) {
          const product = await tx.product.findUnique({
            where: { id: item.productId },
          });
          if (!product || product.stock < item.quantity) {
            throw new BadRequestException(
              `لا يمكن إعادة تفعيل الفاتورة — المخزون غير كافٍ`,
            );
          }
          await tx.product.update({
            where: { id: item.productId },
            data: { stock: { decrement: item.quantity } },
          });
        }
      }

      return tx.invoice.update({
        where: { id },
        data: { status },
        include: {
          customer: true,
          items: { include: { product: true } },
        },
      });
    });
  }

  async updateStatusByNumber(
    number: string,
    status: InvoiceStatus,
    isAdmin: boolean,
  ) {
    const invoice = await this.findByNumber(number);
    return this.updateStatus(invoice.id, status, isAdmin);
  }

  async getSummary(fromDate?: Date, toDate?: Date) {
    const where: Prisma.InvoiceWhereInput = {};
    if (fromDate || toDate) {
      where.date = {};
      if (fromDate) where.date.gte = fromDate;
      if (toDate) where.date.lte = toDate;
    }

    const [totalCount, paid, pending, cancelled, invoices, customers, products] =
      await Promise.all([
        this.prisma.invoice.count({ where }),
        this.prisma.invoice.aggregate({
          where: { ...where, status: InvoiceStatus.PAID },
          _sum: { total: true },
          _count: true,
        }),
        this.prisma.invoice.aggregate({
          where: { ...where, status: InvoiceStatus.PENDING },
          _sum: { total: true },
          _count: true,
        }),
        this.prisma.invoice.count({
          where: { ...where, status: InvoiceStatus.CANCELLED },
        }),
        this.prisma.invoice.findMany({
          where,
          orderBy: { date: 'desc' },
          take: 8,
          include: { customer: { select: { name: true } } },
        }),
        this.prisma.customer.count(),
        this.prisma.product.count(),
      ]);

    return {
      totalInvoices: totalCount,
      paidAmount: paid._sum.total ?? 0,
      paidCount: paid._count,
      pendingAmount: pending._sum.total ?? 0,
      pendingCount: pending._count,
      cancelledCount: cancelled,
      customersCount: customers,
      productsCount: products,
      recentInvoices: invoices,
    };
  }

  async generateReport(params: InvoiceSearchParams) {
    const invoices = await this.findAll({ ...params, limit: 500 });
    const total = invoices.reduce(
      (sum, inv) => sum.add(inv.total),
      new Prisma.Decimal(0),
    );

    return {
      generatedAt: new Date().toISOString(),
      filters: params,
      count: invoices.length,
      totalAmount: total,
      invoices: invoices.map((inv) => ({
        number: inv.number,
        customer: inv.customer.name,
        date: inv.date,
        status: inv.status,
        total: inv.total,
        itemsCount: inv.items.length,
      })),
    };
  }
}
