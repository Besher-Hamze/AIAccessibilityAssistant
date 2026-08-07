export const DATABASE_SCHEMA = `
نظام محاسبة يحتوي على الجداول التالية:

Customers (العملاء):
- id, name, phone, email, address

Products (المنتجات):
- id, name, description, price, stock

Invoices (الفواتير):
- id, number, customerId, total, status (DRAFT|PAID|PENDING|CANCELLED), date, notes

InvoiceItems (بنود الفاتورة):
- invoiceId, productId, quantity, unitPrice, subtotal
`;

export const AI_TOOLS = [
  {
    type: 'function',
    function: {
      name: 'search_customers',
      description: 'البحث عن العملاء بالاسم أو الهاتف أو البريد',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'نص البحث' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'create_customer',
      description: 'إضافة عميل جديد',
      parameters: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          phone: { type: 'string' },
          email: { type: 'string' },
          address: { type: 'string' },
        },
        required: ['name'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'update_customer',
      description: 'تعديل بيانات عميل موجود بالاسم',
      parameters: {
        type: 'object',
        properties: {
          customerName: { type: 'string' },
          name: { type: 'string' },
          phone: { type: 'string' },
          email: { type: 'string' },
          address: { type: 'string' },
        },
        required: ['customerName'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'list_products',
      description: 'عرض قائمة المنتجات والمخزون والأسعار',
      parameters: {
        type: 'object',
        properties: {
          search: { type: 'string', description: 'بحث بالاسم' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'create_product',
      description: 'إضافة منتج جديد',
      parameters: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          description: { type: 'string' },
          price: { type: 'number' },
          stock: { type: 'number' },
        },
        required: ['name', 'price'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'update_product_stock',
      description: 'تحديث مخزون منتج بالاسم',
      parameters: {
        type: 'object',
        properties: {
          productName: { type: 'string' },
          stock: { type: 'number', description: 'الكمية الجديدة للمخزون' },
          price: { type: 'number', description: 'سعر جديد اختياري' },
        },
        required: ['productName'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_customer_invoices',
      description: 'جلب فواتير عميل معين',
      parameters: {
        type: 'object',
        properties: {
          customerName: { type: 'string', description: 'اسم العميل' },
          fromDate: {
            type: 'string',
            description: 'تاريخ البداية ISO مثل 2026-01-01',
          },
          toDate: {
            type: 'string',
            description: 'تاريخ النهاية ISO مثل 2026-01-31',
          },
          status: {
            type: 'string',
            enum: ['DRAFT', 'PAID', 'PENDING', 'CANCELLED'],
          },
        },
        required: ['customerName'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_latest_invoice',
      description: 'جلب آخر فاتورة لعميل أو آخر فاتورة في النظام',
      parameters: {
        type: 'object',
        properties: {
          customerName: {
            type: 'string',
            description: 'اسم العميل (اختياري)',
          },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_invoices',
      description: 'البحث في الفواتير حسب العميل أو الحالة أو الفترة',
      parameters: {
        type: 'object',
        properties: {
          customerName: { type: 'string' },
          status: {
            type: 'string',
            enum: ['DRAFT', 'PAID', 'PENDING', 'CANCELLED'],
          },
          fromDate: { type: 'string' },
          toDate: { type: 'string' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'create_invoice',
      description:
        'إنشاء فاتورة جديدة لعميل بمنتجات وكميات. استخدم أسماء العملاء والمنتجات.',
      parameters: {
        type: 'object',
        properties: {
          customerName: { type: 'string' },
          items: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                productName: { type: 'string' },
                quantity: { type: 'number' },
              },
              required: ['productName', 'quantity'],
            },
          },
          notes: { type: 'string' },
          status: {
            type: 'string',
            enum: ['DRAFT', 'PAID', 'PENDING'],
          },
        },
        required: ['customerName', 'items'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'update_invoice_status',
      description: 'تغيير حالة فاتورة برقمها (مثل INV-00001)',
      parameters: {
        type: 'object',
        properties: {
          invoiceNumber: { type: 'string' },
          status: {
            type: 'string',
            enum: ['DRAFT', 'PAID', 'PENDING', 'CANCELLED'],
          },
        },
        required: ['invoiceNumber', 'status'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_accounting_summary',
      description: 'ملخص المحاسبة: إجمالي الفواتير، المدفوعة، المعلقة',
      parameters: {
        type: 'object',
        properties: {
          fromDate: { type: 'string' },
          toDate: { type: 'string' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'generate_report',
      description: 'إنشاء تقرير فواتير',
      parameters: {
        type: 'object',
        properties: {
          customerName: { type: 'string' },
          fromDate: { type: 'string' },
          toDate: { type: 'string' },
          status: {
            type: 'string',
            enum: ['DRAFT', 'PAID', 'PENDING', 'CANCELLED'],
          },
        },
      },
    },
  },
];

export const SYSTEM_PROMPT = `أنت مساعد محاسبة ذكي باللغة العربية لمساعدة الأشخاص ذوي الإعاقة الحركية.
مهمتك فهم أوامر المستخدم (صوتية أو نصية) وتنفيذ العمليات على نظام المحاسبة.

${DATABASE_SCHEMA}

قواعد مهمة:
1. استخدم الأدوات (functions) المتاحة لتنفيذ الطلبات — لا تخترع بيانات.
2. إذا كان الطلب غامضاً، اطلب توضيحاً بلطف.
3. أجب دائماً بالعربية الفصحى المبسطة.
4. عند عرض النتائج، لخّصها بشكل واضح ومناسب للقراءة الصوتية.
5. التواريخ: "الشهر الماضي" = الشهر السابق من تاريخ اليوم.
6. إذا لم يحدد المستخدم فترة زمنية، نفّذ العملية على كل البيانات بدون طلب توضيح.
7. لا تنفّذ عمليات حذف — غير متاحة للمساعد. استخدم CANCELLED لإلغاء فاتورة.
8. لإنشاء فاتورة استخدم أسماء العملاء والمنتجات الموجودة أو أنشئها أولاً.

تاريخ اليوم: {{TODAY}}
`;
