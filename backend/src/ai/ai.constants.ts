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

export type AiToolDef = {
  type: 'function';
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
};

export const AI_TOOLS: AiToolDef[] = [
  {
    type: 'function',
    function: {
      name: 'list_customers',
      description:
        'عرض كل العملاء أو أسمائهم. استخدمها لأوامر مثل: أعطني أسماء العملاء، اعرض العملاء، قائمة العملاء، شو العملاء، جيب العملاء.',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_customers',
      description:
        'البحث عن عميل بالاسم أو الهاتف. إذا لم يُذكر اسم محدد استخدم list_customers.',
      parameters: {
        type: 'object',
        properties: {
          query: {
            type: 'string',
            description: 'اسم أو جزء من الاسم. اتركه فارغاً لعرض الكل',
          },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'create_customer',
      description: 'إضافة عميل جديد. مثال: أضف عميل اسمه سارة ورقمها 0944',
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
      description:
        'عرض المنتجات والأسعار والمخزون. مثال: اعرض المنتجات، أعطني أسماء المنتجات.',
      parameters: {
        type: 'object',
        properties: {
          search: { type: 'string', description: 'بحث بالاسم اختياري' },
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
      description: 'تحديث مخزون أو سعر منتج بالاسم',
      parameters: {
        type: 'object',
        properties: {
          productName: { type: 'string' },
          stock: { type: 'number' },
          price: { type: 'number' },
        },
        required: ['productName'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_customer_invoices',
      description: 'فواتير عميل معيّن. مثال: اعرض فواتير محمد الأحمد',
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
        required: ['customerName'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_latest_invoice',
      description: 'آخر فاتورة في النظام أو لعميل',
      parameters: {
        type: 'object',
        properties: {
          customerName: { type: 'string' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_invoices',
      description:
        'عرض أو تصفية الفواتير. مثال: أعطني الفواتير، الفواتير المعلقة، فواتير الشهر الماضي.',
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
        'إنشاء فاتورة لعميل بمنتجات وكميات. مثال: أنشئ فاتورة لمحمد بمنتج برنامج محاسبة',
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
      description: 'تغيير حالة فاتورة برقمها مثل INV-SEED-002',
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
      description: 'ملخص المحاسبة: عدد الفواتير والعملاء والمبالغ',
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
