import { PrismaClient, Role, InvoiceStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding Syrian accounting data...');

  const adminPassword = await bcrypt.hash('admin123', 10);
  const userPassword = await bcrypt.hash('user123', 10);

  await prisma.user.upsert({
    where: { email: 'admin@accounting.local' },
    update: {},
    create: {
      email: 'admin@accounting.local',
      password: adminPassword,
      name: 'مدير النظام',
      role: Role.ADMIN,
    },
  });

  await prisma.user.upsert({
    where: { email: 'user@accounting.local' },
    update: {},
    create: {
      email: 'user@accounting.local',
      password: userPassword,
      name: 'مستخدم تجريبي',
      role: Role.USER,
    },
  });

  const customerData = [
    {
      id: 'seed-customer-1',
      name: 'محمد الأحمد',
      phone: '0944123456',
      email: 'mohammed.ahmad@example.com',
      address: 'دمشق - المزة',
    },
    {
      id: 'seed-customer-2',
      name: 'علي الحسين',
      phone: '0933987654',
      email: 'ali.hussein@example.com',
      address: 'حلب - الجميلية',
    },
    {
      id: 'seed-customer-3',
      name: 'فاطمة الخوري',
      phone: '0999112233',
      email: 'fatima.khoury@example.com',
      address: 'حمص - الحي العباسي',
    },
    {
      id: 'seed-customer-4',
      name: 'خالد الدمشقي',
      phone: '0955445566',
      email: 'khaled.dimashqi@example.com',
      address: 'اللاذقية - مشروع الصليبة',
    },
    {
      id: 'seed-customer-5',
      name: 'نورا الحسن',
      phone: '0966778899',
      email: 'noura.hasan@example.com',
      address: 'طرطوس - الكورنيش',
    },
    {
      id: 'seed-customer-6',
      name: 'شركة الشام للتجارة',
      phone: '0112233445',
      email: 'info@alsham.example.com',
      address: 'دمشق - شارع بغداد',
    },
  ];

  const customers = await Promise.all(
    customerData.map((c) =>
      prisma.customer.upsert({
        where: { id: c.id },
        update: {
          name: c.name,
          phone: c.phone,
          email: c.email,
          address: c.address,
        },
        create: c,
      }),
    ),
  );

  // Prices in Syrian Pounds (ل.س)
  const productData = [
    {
      id: 'seed-product-1',
      name: 'خدمة استشارية',
      description: 'ساعة استشارة محاسبية معتمدة',
      price: 250000,
      stock: 999,
    },
    {
      id: 'seed-product-2',
      name: 'برنامج محاسبة',
      description: 'ترخيص سنوي لبرنامج المحاسبة',
      price: 1500000,
      stock: 50,
    },
    {
      id: 'seed-product-3',
      name: 'دفتر حسابات',
      description: 'دفتر حسابات ورقي 200 صفحة',
      price: 35000,
      stock: 200,
    },
    {
      id: 'seed-product-4',
      name: 'طابعة فواتير',
      description: 'طابعة حرارية للفواتير',
      price: 850000,
      stock: 25,
    },
    {
      id: 'seed-product-5',
      name: 'حزمة تدريب محاسبي',
      description: 'دورة تدريبية لمدة 3 أيام',
      price: 2500000,
      stock: 40,
    },
    {
      id: 'seed-product-6',
      name: 'خدمة ضريبية',
      description: 'إعداد وتقديم إقرار ضريبي',
      price: 400000,
      stock: 100,
    },
    {
      id: 'seed-product-7',
      name: 'جهاز نقاط بيع',
      description: 'جهاز POS مع شاشة لمس',
      price: 3200000,
      stock: 15,
    },
    {
      id: 'seed-product-8',
      name: 'ورق حراري',
      description: 'رول ورق حراري 80مم × 10',
      price: 75000,
      stock: 300,
    },
  ];

  const products = await Promise.all(
    productData.map((p) =>
      prisma.product.upsert({
        where: { id: p.id },
        update: {
          name: p.name,
          description: p.description,
          price: p.price,
          stock: p.stock,
        },
        create: p,
      }),
    ),
  );

  const now = new Date();
  const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 15);
  const twoMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 2, 20);

  await prisma.invoiceItem.deleteMany({
    where: { invoice: { number: { startsWith: 'INV-SEED' } } },
  });
  await prisma.invoice.deleteMany({
    where: { number: { startsWith: 'INV-SEED' } },
  });

  const invoices = [
    {
      number: 'INV-SEED-001',
      customerId: customers[0].id,
      total: 850000,
      status: InvoiceStatus.PAID,
      date: lastMonth,
      notes: 'فاتورة شهرية',
      items: [
        {
          productId: products[0].id,
          quantity: 2,
          unitPrice: 250000,
          subtotal: 500000,
        },
        {
          productId: products[2].id,
          quantity: 10,
          unitPrice: 35000,
          subtotal: 350000,
        },
      ],
    },
    {
      number: 'INV-SEED-002',
      customerId: customers[0].id,
      total: 1500000,
      status: InvoiceStatus.PENDING,
      date: new Date(now.getFullYear(), now.getMonth(), 5),
      notes: null,
      items: [
        {
          productId: products[1].id,
          quantity: 1,
          unitPrice: 1500000,
          subtotal: 1500000,
        },
      ],
    },
    {
      number: 'INV-SEED-003',
      customerId: customers[1].id,
      total: 250000,
      status: InvoiceStatus.PAID,
      date: new Date(now.getFullYear(), now.getMonth(), 10),
      notes: null,
      items: [
        {
          productId: products[0].id,
          quantity: 1,
          unitPrice: 250000,
          subtotal: 250000,
        },
      ],
    },
    {
      number: 'INV-SEED-004',
      customerId: customers[2].id,
      total: 3350000,
      status: InvoiceStatus.PAID,
      date: twoMonthsAgo,
      notes: 'عقد تدريب',
      items: [
        {
          productId: products[4].id,
          quantity: 1,
          unitPrice: 2500000,
          subtotal: 2500000,
        },
        {
          productId: products[3].id,
          quantity: 1,
          unitPrice: 850000,
          subtotal: 850000,
        },
      ],
    },
    {
      number: 'INV-SEED-005',
      customerId: customers[3].id,
      total: 3275000,
      status: InvoiceStatus.PENDING,
      date: new Date(now.getFullYear(), now.getMonth(), 12),
      notes: null,
      items: [
        {
          productId: products[6].id,
          quantity: 1,
          unitPrice: 3200000,
          subtotal: 3200000,
        },
        {
          productId: products[7].id,
          quantity: 1,
          unitPrice: 75000,
          subtotal: 75000,
        },
      ],
    },
    {
      number: 'INV-SEED-006',
      customerId: customers[5].id,
      total: 3000000,
      status: InvoiceStatus.PAID,
      date: lastMonth,
      notes: 'ترخيص برامج للشركة',
      items: [
        {
          productId: products[1].id,
          quantity: 2,
          unitPrice: 1500000,
          subtotal: 3000000,
        },
      ],
    },
    {
      number: 'INV-SEED-007',
      customerId: customers[4].id,
      total: 400000,
      status: InvoiceStatus.DRAFT,
      date: new Date(now.getFullYear(), now.getMonth(), 18),
      notes: 'مسودة',
      items: [
        {
          productId: products[5].id,
          quantity: 1,
          unitPrice: 400000,
          subtotal: 400000,
        },
      ],
    },
    {
      number: 'INV-SEED-008',
      customerId: customers[1].id,
      total: 700000,
      status: InvoiceStatus.CANCELLED,
      date: twoMonthsAgo,
      notes: 'أُلغيت بطلب العميل',
      items: [
        {
          productId: products[2].id,
          quantity: 20,
          unitPrice: 35000,
          subtotal: 700000,
        },
      ],
    },
  ];

  for (const inv of invoices) {
    await prisma.invoice.create({
      data: {
        number: inv.number,
        customerId: inv.customerId,
        total: inv.total,
        status: inv.status,
        date: inv.date,
        notes: inv.notes,
        items: { create: inv.items },
      },
    });
  }

  console.log('✅ Seed completed (Syria / SYP)');
  console.log('   Admin: admin@accounting.local / admin123');
  console.log('   User:  user@accounting.local / user123');
  console.log(
    `   Customers: ${customers.length}, Products: ${products.length}, Invoices: ${invoices.length}`,
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
