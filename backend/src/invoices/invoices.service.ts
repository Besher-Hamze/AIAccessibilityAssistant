import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { Prisma, InvoiceStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateInvoiceDto, UpdateInvoiceDto } from './dto/invoice.dto';

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

    const number = await this.nextNumber();

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

  /** The count alone can collide after invoices are removed with a customer. */
  private async nextNumber() {
    let n = (await this.prisma.invoice.count()) + 1;
    for (;;) {
      const number = `INV-${String(n).padStart(5, '0')}`;
      const taken = await this.prisma.invoice.findUnique({ where: { number } });
      if (!taken) return number;
      n++;
    }
  }

  /** Edits items, notes, date or status; stock follows the change in quantities. */
  async update(id: string, dto: UpdateInvoiceDto, isAdmin: boolean) {
    if (!isAdmin) throw new ForbiddenException('ليس لديك صلاحية التعديل');
    const invoice = await this.findOne(id);
    if (dto.items && invoice.status === InvoiceStatus.CANCELLED) {
      throw new BadRequestException('لا يمكن تعديل بنود فاتورة ملغاة');
    }

    await this.prisma.$transaction(async (tx) => {
      const data: Prisma.InvoiceUpdateInput = {};
      if (dto.notes !== undefined) data.notes = dto.notes;
      if (dto.date !== undefined) data.date = new Date(dto.date);

      if (dto.items) {
        const wanted = new Map<string, number>();
        for (const item of dto.items) {
          wanted.set(
            item.productId,
            (wanted.get(item.productId) ?? 0) + item.quantity,
          );
        }
        const old = new Map(invoice.items.map((i) => [i.productId, i]));
        const ids = new Set([...wanted.keys(), ...old.keys()]);
        const products = await tx.product.findMany({
          where: { id: { in: [...ids] } },
        });
        const productMap = new Map(products.map((p) => [p.id, p]));

        let total = new Prisma.Decimal(0);
        const created: Prisma.InvoiceItemCreateWithoutInvoiceInput[] = [];
        for (const productId of ids) {
          const product = productMap.get(productId);
          if (!product) throw new BadRequestException('أحد المنتجات غير موجود');
          const quantity = wanted.get(productId) ?? 0;
          const delta = quantity - (old.get(productId)?.quantity ?? 0);
          if (delta > product.stock) {
            throw new BadRequestException(
              `المخزون غير كافٍ للمنتج: ${product.name} (المتاح: ${product.stock})`,
            );
          }
          if (delta !== 0) {
            await tx.product.update({
              where: { id: productId },
              data: { stock: { decrement: delta } },
            });
          }
          if (quantity > 0) {
            // A kept line keeps the price it was sold at.
            const unitPrice = old.get(productId)?.unitPrice ?? product.price;
            const subtotal = unitPrice.mul(quantity);
            total = total.add(subtotal);
            created.push({
              product: { connect: { id: productId } },
              quantity,
              unitPrice,
              subtotal,
            });
          }
        }
        data.total = total;
        data.items = { deleteMany: {}, create: created };
      }

      await tx.invoice.update({ where: { id }, data });
    });

    if (dto.status && dto.status !== invoice.status) {
      return this.updateStatus(id, dto.status, isAdmin);
    }
    return this.findOne(id);
  }

  private itemsAsDto(invoice: {
    items: { productId: string; quantity: number }[];
  }) {
    return invoice.items.map((i) => ({
      productId: i.productId,
      quantity: i.quantity,
    }));
  }

  async addItemByName(
    number: string,
    productName: string,
    quantity: number,
    isAdmin: boolean,
  ) {
    const invoice = await this.findByNumber(number);
    const product = await this.prisma.product.findFirst({
      where: { name: { contains: productName, mode: 'insensitive' } },
    });
    if (!product) {
      throw new BadRequestException(`المنتج غير موجود: ${productName}`);
    }
    return this.update(
      invoice.id,
      {
        items: [
          ...this.itemsAsDto(invoice),
          { productId: product.id, quantity },
        ],
      },
      isAdmin,
    );
  }

  async removeItemByName(number: string, productName: string, isAdmin: boolean) {
    const invoice = await this.findByNumber(number);
    const items = invoice.items.filter(
      (i) => !i.product.name.toLowerCase().includes(productName.toLowerCase()),
    );
    if (items.length === invoice.items.length) {
      throw new BadRequestException(`المنتج ليس في الفاتورة: ${productName}`);
    }
    if (!items.length) {
      throw new BadRequestException(
        'لا يمكن حذف البند الوحيد. يمكنك إلغاء الفاتورة بدلاً من ذلك',
      );
    }
    return this.update(
      invoice.id,
      { items: this.itemsAsDto({ items }) },
      isAdmin,
    );
  }

  private billedWhere(fromDate?: Date, toDate?: Date): Prisma.InvoiceWhereInput {
    const where: Prisma.InvoiceWhereInput = {
      status: { in: [InvoiceStatus.PAID, InvoiceStatus.PENDING] },
    };
    if (fromDate || toDate) {
      where.date = {};
      if (fromDate) where.date.gte = fromDate;
      if (toDate) where.date.lte = toDate;
    }
    return where;
  }

  async topCustomers(limit = 5, fromDate?: Date, toDate?: Date) {
    const rows = await this.prisma.invoice.groupBy({
      by: ['customerId'],
      where: this.billedWhere(fromDate, toDate),
      _sum: { total: true },
      _count: true,
      orderBy: { _sum: { total: 'desc' } },
      take: limit,
    });
    return this.withCustomerNames(rows);
  }

  /** Customers who still owe money (pending invoices), largest balance first. */
  async customersWithBalance() {
    const rows = await this.prisma.invoice.groupBy({
      by: ['customerId'],
      where: { status: InvoiceStatus.PENDING },
      _sum: { total: true },
      _count: true,
      orderBy: { _sum: { total: 'desc' } },
    });
    return this.withCustomerNames(rows);
  }

  private async withCustomerNames(
    rows: {
      customerId: string;
      _sum: { total: Prisma.Decimal | null };
      _count: number;
    }[],
  ) {
    const customers = await this.prisma.customer.findMany({
      where: { id: { in: rows.map((r) => r.customerId) } },
      select: { id: true, name: true },
    });
    const names = new Map(customers.map((c) => [c.id, c.name]));
    return rows.map((r) => ({
      customerId: r.customerId,
      name: names.get(r.customerId) ?? '',
      amount: r._sum.total ?? 0,
      invoices: r._count,
    }));
  }

  async topProducts(limit = 5, fromDate?: Date, toDate?: Date) {
    const rows = await this.prisma.invoiceItem.groupBy({
      by: ['productId'],
      where: { invoice: this.billedWhere(fromDate, toDate) },
      _sum: { quantity: true, subtotal: true },
      orderBy: { _sum: { quantity: 'desc' } },
      take: limit,
    });
    const products = await this.prisma.product.findMany({
      where: { id: { in: rows.map((r) => r.productId) } },
      select: { id: true, name: true },
    });
    const names = new Map(products.map((p) => [p.id, p.name]));
    return rows.map((r) => ({
      productId: r.productId,
      name: names.get(r.productId) ?? '',
      quantity: r._sum.quantity ?? 0,
      amount: r._sum.subtotal ?? 0,
    }));
  }

  async salesByMonth(months = 6) {
    const from = new Date();
    from.setMonth(from.getMonth() - (months - 1), 1);
    from.setHours(0, 0, 0, 0);
    const invoices = await this.prisma.invoice.findMany({
      where: this.billedWhere(from),
      select: { date: true, total: true },
    });
    const totals = new Map<string, { amount: Prisma.Decimal; invoices: number }>();
    for (const inv of invoices) {
      const key = inv.date.toISOString().slice(0, 7);
      const row = totals.get(key) ?? {
        amount: new Prisma.Decimal(0),
        invoices: 0,
      };
      row.amount = row.amount.add(inv.total);
      row.invoices++;
      totals.set(key, row);
    }
    return [...totals.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([month, row]) => ({ month, ...row }));
  }

  async insights() {
    const [topCustomers, topProducts, balances, sales] = await Promise.all([
      this.topCustomers(),
      this.topProducts(),
      this.customersWithBalance(),
      this.salesByMonth(),
    ]);
    return { topCustomers, topProducts, balances, sales };
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
