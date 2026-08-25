import { AI_TOOLS, DATABASE_SCHEMA } from './ai.constants';

/** Phrase → tool catalog used in the system prompt and JSON fallback. */
export const COMMAND_CATALOG: Array<{
  tool: string;
  phrases: string[];
}> = [
  {
    tool: 'list_customers',
    phrases: [
      'أعطني أسماء العملاء',
      'اعرض العملاء',
      'قائمة العملاء',
      'شو العملاء',
      'جيب العملاء',
      'أسماء العملاء',
      'كل العملاء',
      'نادي العملاء',
    ],
  },
  {
    tool: 'search_customers',
    phrases: [
      'ابحث عن العميل محمد',
      'وين عميل اسمه علي',
      'فين العميل خالد',
    ],
  },
  {
    tool: 'create_customer',
    phrases: [
      'أضف عميل اسمه سارة ورقمها 0944001122',
      'سجل عميل جديد اسمه أحمد',
    ],
  },
  {
    tool: 'update_customer',
    phrases: ['عدّل هاتف العميل خالد إلى 0999', 'غيّر عنوان العميل محمد'],
  },
  {
    tool: 'list_products',
    phrases: [
      'أعطني المنتجات',
      'اعرض المنتجات',
      'قائمة المنتجات',
      'أسماء المنتجات',
      'شو المخزون',
    ],
  },
  {
    tool: 'create_product',
    phrases: ['أضف منتج اسمه دفتر حسابات سعره 35000'],
  },
  {
    tool: 'update_product_stock',
    phrases: ['غيّر مخزون منتج طابعة إلى 10', 'اجعل سعر المنتج دفتر 40000'],
  },
  {
    tool: 'search_invoices',
    phrases: [
      'أعطني الفواتير',
      'اعرض الفواتير',
      'الفواتير المعلقة',
      'فواتير الشهر الماضي',
      'الفواتير المدفوعة',
    ],
  },
  {
    tool: 'get_customer_invoices',
    phrases: ['اعرض فواتير محمد الأحمد', 'فواتير العميل علي'],
  },
  {
    tool: 'get_latest_invoice',
    phrases: ['آخر فاتورة', 'آخر فاتورة لعلي الحسين'],
  },
  {
    tool: 'create_invoice',
    phrases: ['أنشئ فاتورة لمحمد الأحمد بمنتج برنامج محاسبة'],
  },
  {
    tool: 'update_invoice_status',
    phrases: ['غيّر حالة الفاتورة INV-SEED-002 إلى مدفوعة'],
  },
  {
    tool: 'get_accounting_summary',
    phrases: [
      'ما ملخص المحاسبة؟',
      'كم عدد الفواتير',
      'إجمالي المحاسبة',
      'حال المحاسبة',
    ],
  },
  {
    tool: 'generate_report',
    phrases: [
      'أنشئ تقريراً عن الفواتير المعلقة',
      'تقرير لفواتير محمد الأحمد',
    ],
  },
];

function catalogLines(): string {
  return COMMAND_CATALOG.map(
    (row) => `- ${row.phrases.join(' | ')} → ${row.tool}`,
  ).join('\n');
}

function toolLines(): string {
  return AI_TOOLS.map(
    (t) => `- ${t.function.name}: ${t.function.description}`,
  ).join('\n');
}

export function buildSystemPrompt(today: string): string {
  return `أنت مساعد محاسبة عربي لنظام محاسب+. مهمتك تنفيذ أوامر المستخدم عبر استدعاء أداة واحدة فقط.
لا تخترع بيانات. لا تقل "لم أفهم طلبك" إذا الأمر يتعلق بعملاء أو منتجات أو فواتير أو ملخص أو تقرير — استدعِ الأداة المناسبة فوراً.

${DATABASE_SCHEMA}

خريطة الأوامر → الأداة (نفّذ بدون سؤال توضيحي):
${catalogLines()}

قواعد:
1. لطلبات العرض أو الأسماء أو القوائم استدعِ الأداة دائماً. الرد النصي فقط للتحية أو إذا نقص اسم ضروري للإنشاء (مثل إنشاء فاتورة بدون عميل).
2. "أعطني أسماء العملاء" و"قائمة العملاء" و"اعرض العملاء" = list_customers وليس بحثاً.
3. أجب بالعربية المبسطة المناسبة للقراءة الصوتية.
4. الشهر الماضي = الشهر السابق من اليوم. إذا لم تُحدد فترة استخدم كل البيانات.
5. لا حذف. لإلغاء فاتورة استخدم الحالة CANCELLED.
6. العملة ليرة سورية.

تاريخ اليوم: ${today}
`;
}

export function buildJsonFallbackPrompt(today: string): string {
  return `${buildSystemPrompt(today)}

الأدوات المتاحة:
${toolLines()}

أجب بـ JSON فقط:
{"tool": "اسم_الأداة", "arguments": {}}

أمثلة إلزامية:
{"tool": "list_customers", "arguments": {}}
{"tool": "list_products", "arguments": {}}
{"tool": "search_invoices", "arguments": {}}
{"tool": "get_accounting_summary", "arguments": {}}

لا تستخدم {"tool": null} لطلب بيانات أو قائمة أو أسماء. tool:null مسموح فقط للتحية مثل مرحبا.
`;
}

export function buildFinalReplyPrompt(): string {
  return `لخّص نتيجة العملية للمستخدم بالعربية بشكل واضح ومختصر ومناسب للقراءة الصوتية.
إذا كانت النتيجة قائمة عملاء فاذكر أسماءهم. لا تقل لم أفهم. لا تستخدم JSON.`;
}
