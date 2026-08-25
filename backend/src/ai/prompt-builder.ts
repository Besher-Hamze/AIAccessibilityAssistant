import { AI_TOOLS, DATABASE_SCHEMA } from './ai.constants';

/** Example phrasings — the model must treat them as meaning, not required wording. */
export const COMMAND_CATALOG: Array<{
  tool: string;
  goal: string;
  phrases: string[];
}> = [
  {
    tool: 'list_customers',
    goal: 'عرض كل العملاء أو أسمائهم',
    phrases: ['أسماء الزباين', 'مين العملاء عندي', 'طلع لي العملاء'],
  },
  {
    tool: 'search_customers',
    goal: 'البحث عن عميل معيّن بالاسم أو الهاتف',
    phrases: ['في عندي زبون اسمه محمد؟', 'وين رقم علي'],
  },
  {
    tool: 'create_customer',
    goal: 'إضافة عميل جديد',
    phrases: ['سجّل زبون اسمه سارة ورقمها 0944', 'بدي ضيف عميل جديد'],
  },
  {
    tool: 'update_customer',
    goal: 'تعديل بيانات عميل موجود',
    phrases: ['غيّر تلفون خالد', 'حدّث عنوان محمد'],
  },
  {
    tool: 'list_products',
    goal: 'عرض المنتجات أو المخزون أو الأسعار',
    phrases: ['شو المنتجات', 'طلع لي البضاعة', 'كم المخزون'],
  },
  {
    tool: 'create_product',
    goal: 'إضافة منتج جديد',
    phrases: ['ضيف منتج دفتر سعره 35000'],
  },
  {
    tool: 'update_product_stock',
    goal: 'تعديل مخزون أو سعر منتج',
    phrases: ['خلّي مخزون الطابعة 10', 'سعّر الدفتر 40000'],
  },
  {
    tool: 'search_invoices',
    goal: 'عرض أو تصفية الفواتير بدون اسم عميل إلزامي',
    phrases: ['طلع الفواتير', 'الفواتير اللي معلّقة', 'فواتير الشهر اللي فات'],
  },
  {
    tool: 'get_customer_invoices',
    goal: 'فواتير عميل معيّن بالاسم',
    phrases: ['فواتير محمد شو صارت', 'حساب علي'],
  },
  {
    tool: 'get_latest_invoice',
    goal: 'آخر فاتورة عامة أو لعميل',
    phrases: ['آخر فاتورة', 'آخر فاتورة لعلي'],
  },
  {
    tool: 'create_invoice',
    goal: 'إنشاء فاتورة لعميل بمنتج/كمية',
    phrases: ['اعمل فاتورة لمحمد على برنامج المحاسبة'],
  },
  {
    tool: 'update_invoice_status',
    goal: 'تغيير حالة فاتورة برقمها',
    phrases: ['خلّي الفاتورة INV-SEED-002 مدفوعة'],
  },
  {
    tool: 'get_accounting_summary',
    goal: 'ملخص الأرقام: عدد العملاء/الفواتير والمبالغ',
    phrases: ['شو وضع المحاسبة', 'كم طلّعنا', 'لمحة سريعة'],
  },
  {
    tool: 'generate_report',
    goal: 'إنشاء تقرير فواتير',
    phrases: ['جهّز تقرير للمعلقات', 'تقرير فواتير محمد'],
  },
];

function catalogLines(): string {
  return COMMAND_CATALOG.map(
    (row) =>
      `- الهدف: ${row.goal} → ${row.tool}\n  أمثلة حرة (ليست صيغة إلزامية): ${row.phrases.join(' / ')}`,
  ).join('\n');
}

function toolLines(): string {
  return AI_TOOLS.map(
    (t) => `- ${t.function.name}: ${t.function.description}`,
  ).join('\n');
}

export function buildSystemPrompt(today: string): string {
  return `أنت مساعد محاسبة عربي لنظام محاسب+. المستخدم يتكلم بحرية: فصحى أو عامية سورية، جمل ناقصة، أخطاء إملائية، وأخطاء تحويل الصوت إلى نص.
مهمتك فهم المقصود (الهدف) ثم استدعاء أداة واحدة فقط. لا تنتظر صياغة ثابتة.

${DATABASE_SCHEMA}

اختر الأداة حسب الهدف:
${catalogLines()}

قواعد الاختيار:
1. إذا طلب أي قائمة/أسماء/عرض للعملاء بدون اسم شخص محدد → list_customers.
2. إذا ذكر اسم عميل للبحث عنه → search_customers. إذا ذكر اسم عميل لعرض فواتيره → get_customer_invoices.
3. لا تقل "لم أفهم" لطلبات المحاسبة. استدعِ أقرب أداة مناسبة.
4. الرد النصي بدون أداة مسموح فقط للتحية أو إذا نقص معطى ضروري للإنشاء (مثل إنشاء فاتورة بدون أي عميل أو منتج).
5. أجب بالعربية المبسطة المناسبة للقراءة الصوتية. العملة ليرة سورية.
6. لا حذف. لإلغاء فاتورة استخدم CANCELLED. إذا لم تُحدد فترة زمنية استخدم كل البيانات.

تاريخ اليوم: ${today}
`;
}

export function buildJsonFallbackPrompt(today: string): string {
  return `${buildSystemPrompt(today)}

الأدوات المتاحة:
${toolLines()}

أجب بـ JSON فقط بدون شرح:
{"tool": "اسم_الأداة", "arguments": {}}

أمثلة حسب الهدف وليس الصيغة:
طلب أسماء/قائمة العملاء → {"tool": "list_customers", "arguments": {}}
طلب منتجات/مخزون → {"tool": "list_products", "arguments": {}}
طلب الفواتير عامة → {"tool": "search_invoices", "arguments": {}}
ملخص/كم العدد → {"tool": "get_accounting_summary", "arguments": {}}
بحث عن محمد → {"tool": "search_customers", "arguments": {"query": "محمد"}}

tool:null مسموح فقط للتحية مثل مرحبا.
`;
}

export function buildFinalReplyPrompt(): string {
  return `لخّص نتيجة العملية للمستخدم بالعربية بشكل واضح ومختصر ومناسب للقراءة الصوتية.
إذا كانت النتيجة قائمة عملاء فاذكر أسماءهم. لا تقل لم أفهم. لا تستخدم JSON.`;
}

export const TOOL_NAMES = AI_TOOLS.map((t) => t.function.name);
