import { PrismaClient, Role, InvoiceStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database...');

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
      name: 'محمد أحمد',
      phone: '0501234567',
      email: 'mohammed@example.com',
      address: 'الرياض - حي النرجس',
    },
    {
      id: 'seed-customer-2',
      name: 'علي حسن',
      phone: '0509876543',
      email: 'ali@example.com',
      address: 'جدة - حي الروضة',
    },
    {
      id: 'seed-customer-3',
      name: 'فاطمة سعيد',
      phone: '0551112233',
      email: 'fatima@example.com',
      address: 'الدمام - حي الشاطئ',
    },
    {
      id: 'seed-customer-4',
      name: 'خالد العتيبي',
      phone: '0534445566',
      email: 'khaled@example.com',
      address: 'مكة المكرمة',
    },
    {
      id: 'seed-customer-5',
      name: 'نورة الشمري',
      phone: '0547778899',
      email: 'noura@example.com',
      address: 'المدينة المنورة',
    },
    {
      id: 'seed-customer-6',
      name: 'شركة النور للتجارة',
      phone: '0112345678',
      email: 'info@alnoor.example.com',
      address: 'الرياض - طريق الملك فهد',
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

  const productData = [
    {
      id: 'seed-product-1',
      name: 'خدمة استشارية',
      description: 'ساعة استشارة محاسبية معتمدة',
      price: 500,
      stock: 999,
    },
    {
      id: 'seed-product-2',
      name: 'برنامج محاسبة',
      description: 'ترخيص سنوي لبرنامج المحاسبة',
      price: 1200,
      stock: 50,
    },
    {
      id: 'seed-product-3',
      name: 'دفتر حسابات',
      description: 'دفتر حسابات ورقي 200 صفحة',
      price: 45,
      stock: 200,
    },
    {
      id: 'seed-product-4',
      name: 'طابعة فواتير',
      description: 'طابعة حرارية للفواتير',
      price: 850,
      stock: 25,
    },
    {
      id: 'seed-product-5',
      name: 'حزمة تدريب محاسبي',
      description: 'دورة تدريبية لمدة 3 أيام',
      price: 2500,
      stock: 40,
    },
    {
      id: 'seed-product-6',
      name: 'رخصة ضريبية',
      description: 'خدمة استخراج رخصة ضريبية',
      price: 350,
      stock: 100,
    },
    {
      id: 'seed-product-7',
      name: 'جهاز نقاط بيع',
      description: 'جهاز POS مع شاشة لمس',
      price: 1800,
      stock: 15,
    },
    {
      id: 'seed-product-8',
      name: 'ورق حراري',
      description: 'رول ورق حراري 80مم × 10',
      price: 60,
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
      total: 1450,
      status: InvoiceStatus.PAID,
      date: lastMonth,
      notes: 'فاتورة شهرية',
      items: [
        { productId: products[0].id, quantity: 2, unitPrice: 500, subtotal: 1000 },
        { productId: products[2].id, quantity: 10, unitPrice: 45, subtotal: 450 },
      ],
    },
    {
      number: 'INV-SEED-002',
      customerId: customers[0].id,
      total: 1200,
      status: InvoiceStatus.PENDING,
      date: new Date(now.getFullYear(), now.getMonth(), 5),
      notes: null,
      items: [
        { productId: products[1].id, quantity: 1, unitPrice: 1200, subtotal: 1200 },
      ],
    },
    {
      number: 'INV-SEED-003',
      customerId: customers[1].id,
      total: 500,
      status: InvoiceStatus.PAID,
      date: new Date(now.getFullYear(), now.getMonth(), 10),
      notes: null,
      items: [
        { productId: products[0].id, quantity: 1, unitPrice: 500, subtotal: 500 },
      ],
    },
    {
      number: 'INV-SEED-004',
      customerId: customers[2].id,
      total: 3350,
      status: InvoiceStatus.PAID,
      date: twoMonthsAgo,
      notes: 'عقد تدريب',
      items: [
        { productId: products[4].id, quantity: 1, unitPrice: 2500, subtotal: 2500 },
        { productId: products[3].id, quantity: 1, unitPrice: 850, subtotal: 850 },
      ],
    },
    {
      number: 'INV-SEED-005',
      customerId: customers[3].id,
      total: 1860,
      status: InvoiceStatus.PENDING,
      date: new Date(now.getFullYear(), now.getMonth(), 12),
      notes: null,
      items: [
        { productId: products[6].id, quantity: 1, unitPrice: 1800, subtotal: 1800 },
        { productId: products[7].id, quantity: 1, unitPrice: 60, subtotal: 60 },
      ],
    },
    {
      number: 'INV-SEED-006',
      customerId: customers[5].id,
      total: 2400,
      status: InvoiceStatus.PAID,
      date: lastMonth,
      notes: 'ترخيص برامج للشركة',
      items: [
        { productId: products[1].id, quantity: 2, unitPrice: 1200, subtotal: 2400 },
      ],
    },
    {
      number: 'INV-SEED-007',
      customerId: customers[4].id,
      total: 350,
      status: InvoiceStatus.DRAFT,
      date: new Date(now.getFullYear(), now.getMonth(), 18),
      notes: 'مسودة',
      items: [
        { productId: products[5].id, quantity: 1, unitPrice: 350, subtotal: 350 },
      ],
    },
    {
      number: 'INV-SEED-008',
      customerId: customers[1].id,
      total: 900,
      status: InvoiceStatus.CANCELLED,
      date: twoMonthsAgo,
      notes: 'أُلغيت بطلب العميل',
      items: [
        { productId: products[2].id, quantity: 20, unitPrice: 45, subtotal: 900 },
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

  console.log('✅ Seed completed');
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
