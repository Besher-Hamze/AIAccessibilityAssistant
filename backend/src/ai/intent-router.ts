/**
 * Deterministic Arabic voice-command matcher.
 * Runs before the LLM so common phrases never fall through to "لم أفهم".
 */

export type MatchedIntent = {
  tool: string;
  args: Record<string, unknown>;
};

const STATUS_MAP: Record<string, string> = {
  مدفوعه: 'PAID',
  مدفوعة: 'PAID',
  معلقه: 'PENDING',
  معلقة: 'PENDING',
  مسوده: 'DRAFT',
  مسودة: 'DRAFT',
  ملغاه: 'CANCELLED',
  ملغاة: 'CANCELLED',
};

export function normalizeAr(text: string): string {
  return text
    .replace(/[\u064B-\u0652]/g, '')
    .replace(/[إأآا]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .replace(/ؤ/g, 'و')
    .replace(/ئ/g, 'ي')
    .replace(/ء/g, '')
    .replace(/[٠-٩]/g, (d) => String('٠١٢٣٤٥٦٧٨٩'.indexOf(d)))
    .replace(/\s+/g, ' ')
    .trim();
}

function pickStatus(text: string): string | undefined {
  const n = normalizeAr(text);
  if (n.includes('مدفوع')) return 'PAID';
  if (n.includes('معلق')) return 'PENDING';
  if (n.includes('مسود')) return 'DRAFT';
  if (n.includes('ملغ')) return 'CANCELLED';
  return undefined;
}

function after(text: string, pattern: RegExp): string | undefined {
  const m = text.match(pattern);
  const value = m?.[1]?.trim();
  return value && value.length > 0 ? value : undefined;
}

function has(n: string, ...parts: string[]): boolean {
  return parts.some((p) => n.includes(normalizeAr(p)));
}

function isCreate(n: string): boolean {
  return has(n, 'اضف', 'انشئ', 'سجل', 'جديد');
}

function talksInvoice(n: string): boolean {
  return has(n, 'فاتور', 'فواتير', 'فواتي');
}

export function matchIntent(message: string): MatchedIntent | null {
  const raw = message.trim();
  const n = normalizeAr(raw);
  if (!n) return null;

  if (
    has(n, 'ملخص', 'اجمالي', 'الاحصائ', 'حال المحاس') ||
    /كم\s*(عدد\s*)?(الفواتير|العملا|المنتجات)/.test(n)
  ) {
    return { tool: 'get_accounting_summary', args: {} };
  }

  if (has(n, 'تقرير')) {
    const status = pickStatus(raw);
    const customerName = after(raw, /(?:لفواتير|لعميل|للعميل)\s+(.+)$/i);
    const args: Record<string, unknown> = {};
    if (status) args.status = status;
    if (customerName) {
      args.customerName = customerName.replace(/المعلق.*$/, '').trim();
    }
    return { tool: 'generate_report', args };
  }

  if (isCreate(n) && has(n, 'عميل') && !talksInvoice(n)) {
    const name =
      after(raw, /(?:اسمه|اسمها|اسم)\s+(.+?)(?:\s+و?(?:رقم|هاتف|جوال)|$)/) ||
      after(raw, /عميل\s+(.+?)(?:\s+و?(?:رقم|هاتف|جوال)|$)/);
    const phone = after(raw, /(?:رقم(?:ها|ه)?|هاتف|جوال)\s*([0-9]{4,})/);
    if (name && !has(normalizeAr(name), 'اسماء', 'قائمه', 'كل')) {
      return {
        tool: 'create_customer',
        args: { name: name.trim(), ...(phone ? { phone } : {}) },
      };
    }
  }

  if (isCreate(n) && has(n, 'منتج') && !talksInvoice(n)) {
    const name = after(raw, /(?:اسمه|اسمها|اسم)\s+(.+?)(?:\s+سعر|$)/);
    const price = after(n, /سعر(?:ه|ها)?\s*([0-9]+)/);
    if (name && price) {
      return {
        tool: 'create_product',
        args: { name: name.trim(), price: Number(price) },
      };
    }
  }

  if (
    (has(n, 'غير', 'حدث', 'حول', 'خلي') && talksInvoice(n) && has(n, 'حال')) ||
    /اجعل\s*الفاتور/.test(n)
  ) {
    const invoiceNumber =
      after(raw, /(INV[-_][A-Za-z0-9-]+)/i) ||
      after(n, /فاتور(?:ه)?\s+([A-Za-z0-9-_]+)/i);
    const status = pickStatus(raw);
    if (invoiceNumber && status) {
      return {
        tool: 'update_invoice_status',
        args: { invoiceNumber: invoiceNumber.toUpperCase(), status },
      };
    }
  }

  if (
    has(n, 'مخزون') &&
    (has(n, 'غير', 'حدث', 'خلي', 'اجعل') || has(n, 'سعر'))
  ) {
    const productName =
      after(raw, /منتج\s+(.+?)(?:\s+الى|\s+إلى|\s+سعر|$)/) ||
      after(raw, /مخزون\s+(.+?)(?:\s+الى|\s+إلى|$)/);
    const stock = after(n, /(?:الى|الي|يصير)\s*([0-9]+)/);
    const price = after(n, /سعر(?:ه|ها)?\s*([0-9]+)/);
    if (productName && (stock || price)) {
      return {
        tool: 'update_product_stock',
        args: {
          productName: productName.trim(),
          ...(stock ? { stock: Number(stock) } : {}),
          ...(price ? { price: Number(price) } : {}),
        },
      };
    }
  }

  if (isCreate(n) && talksInvoice(n)) {
    const customerName =
      after(raw, /فاتور[هة]?\s+ل(?:لعميل)?\s*(.+?)(?:\s+بمنتج|\s+منتج|$)/) ||
      after(raw, /(?:للعميل|عميل)\s+(.+?)(?:\s+بمنتج|\s+منتج|$)/);
    const productName =
      after(raw, /بمنتج\s+(.+?)(?:\s+كميه|\s+عدد|$)/) ||
      after(raw, /منتج\s+(.+)$/);
    const qtyRaw = after(n, /(?:كميه|عدد)\s*([0-9]+)/);
    if (customerName && productName) {
      return {
        tool: 'create_invoice',
        args: {
          customerName: customerName.trim(),
          items: [
            {
              productName: productName.trim(),
              quantity: qtyRaw ? Number(qtyRaw) : 1,
            },
          ],
        },
      };
    }
  }

  if (has(n, 'اخر') && talksInvoice(n)) {
    const customerName = after(raw, /(?:ل|للعميل|عميل)\s*(.+)$/i);
    return {
      tool: 'get_latest_invoice',
      args: customerName ? { customerName } : {},
    };
  }

  if (
    has(n, 'عدل', 'غير', 'حدث') &&
    has(n, 'عميل') &&
    !talksInvoice(n) &&
    !isCreate(n)
  ) {
    const customerName =
      after(raw, /العميل\s+(.+?)(?:\s+الى|\s+إلى|\s+ل|$)/) ||
      after(raw, /عميل\s+(.+)$/);
    const phone = after(raw, /(?:هاتف|رقم|جوال)\s*(?:الى|إلى)?\s*([0-9]+)/);
    const address = after(raw, /عنوان(?:ه|ها)?\s+(?:الى|إلى)?\s*(.+)$/);
    if (customerName && (phone || address)) {
      return {
        tool: 'update_customer',
        args: {
          customerName: customerName.trim(),
          ...(phone ? { phone } : {}),
          ...(address ? { address } : {}),
        },
      };
    }
  }

  // List ALL customers — "اعطني اسماء العملاء"
  if (
    has(n, 'عميل', 'عملا') &&
    !isCreate(n) &&
    !talksInvoice(n) &&
    (has(n, 'اسم', 'اسما', 'قائمه', 'عرض', 'اعط', 'اريد', 'جيب', 'نادي', 'كل ') ||
      /^(العملا|شو العملا|العملاء)$/.test(n) ||
      (/ابحث|بحث/.test(n) === false && /العملا/.test(n) && !/عن\s+\S+/.test(n)))
  ) {
    const named =
      after(raw, /(?:عن(?: العميل)?|العميل)\s+([^\s].+)$/) ||
      after(raw, /عميل\s+(?!جديد)(.+)$/);
    const looksLikeName =
      named &&
      named.length > 1 &&
      !has(normalizeAr(named), 'اسما', 'قائمه', 'كل', 'رقم');
    if (looksLikeName && has(n, 'ابحث', 'بحث', 'فين', 'وين')) {
      return { tool: 'search_customers', args: { query: named } };
    }
    if (!looksLikeName || has(n, 'اسما', 'قائمه', 'كل', 'اعط', 'جيب', 'عرض')) {
      return { tool: 'list_customers', args: {} };
    }
    return { tool: 'search_customers', args: { query: named } };
  }

  if (/بحث|ابحث/.test(n) && has(n, 'عميل', 'عملا')) {
    const query =
      after(raw, /(?:العميل|عميل)\s+(.+)$/) || after(raw, /عن\s+(.+)$/);
    return { tool: 'search_customers', args: { query: query || '' } };
  }

  if (
    has(n, 'منتج') &&
    !talksInvoice(n) &&
    !isCreate(n) &&
    (has(n, 'قائمه', 'عرض', 'اعط', 'اريد', 'جيب', 'اسم', 'كل ', 'مخزون') ||
      /المنتجات/.test(n))
  ) {
    const search = after(raw, /منتج(?:ات)?\s+(?:اسمه|اسمها)?\s*(.+)$/i);
    const skip = search && has(normalizeAr(search), 'اسما', 'قائمه', 'كل');
    return {
      tool: 'list_products',
      args: search && !skip ? { search } : {},
    };
  }

  if (talksInvoice(n) && !isCreate(n) && !has(n, 'غير', 'حدث')) {
    const status = pickStatus(raw);
    const customerName =
      after(raw, /(?:فواتير|فاتورة)\s+(.+)$/) ||
      after(raw, /(?:للعميل|ل)\s+(.+)$/);
    const args: Record<string, unknown> = {};
    if (status) args.status = status;
    if (customerName && !STATUS_MAP[normalizeAr(customerName)]) {
      const cleaned = customerName
        .replace(/المعلق.*|المدفوع.*|الشهر.*|كل.*|اسما.*/g, '')
        .trim();
      if (
        cleaned &&
        !has(normalizeAr(cleaned), 'قائمه', 'كل', 'المعلق', 'المدفوع')
      ) {
        args.customerName = cleaned;
      }
    }
    if (/شهر\s*الماضي/.test(n)) {
      const d = new Date();
      const from = new Date(d.getFullYear(), d.getMonth() - 1, 1);
      const to = new Date(d.getFullYear(), d.getMonth(), 0);
      args.fromDate = from.toISOString().slice(0, 10);
      args.toDate = to.toISOString().slice(0, 10);
    }
    if (args.customerName) return { tool: 'get_customer_invoices', args };
    return { tool: 'search_invoices', args };
  }

  return null;
}

function money(v: unknown): string {
  const n = Number(v ?? 0);
  return Number.isFinite(n) ? n.toLocaleString('en') : String(v ?? 0);
}

export function formatToolReply(
  tool: string,
  result: unknown,
  args: Record<string, unknown>,
): string {
  const list = Array.isArray(result) ? result : [];

  switch (tool) {
    case 'get_accounting_summary': {
      const s = (result ?? {}) as Record<string, unknown>;
      return (
        `الملخص: ${s.totalInvoices ?? 0} فاتورة، ` +
        `${s.customersCount ?? 0} عميل، ${s.productsCount ?? 0} منتج. ` +
        `المدفوع ${money(s.paidAmount)} ليرة (${s.paidCount ?? 0})، ` +
        `والمعلق ${money(s.pendingAmount)} ليرة (${s.pendingCount ?? 0}).`
      );
    }
    case 'list_customers':
    case 'search_customers': {
      if (!list.length) return 'لا يوجد عملاء مطابقون.';
      const names = list
        .map((c) => (c as Record<string, unknown>).name)
        .filter(Boolean);
      return `أسماء العملاء: ${names.join('، ')}. العدد ${names.length}.`;
    }
    case 'create_customer': {
      const c = result as Record<string, unknown>;
      return `تمت إضافة العميل ${c.name ?? args.name}.`;
    }
    case 'update_customer': {
      const c = result as Record<string, unknown>;
      return `تم تعديل بيانات العميل ${c.name ?? args.customerName}.`;
    }
    case 'list_products':
      if (!list.length) return 'لا توجد منتجات مطابقة.';
      return `المنتجات: ${list
        .slice(0, 12)
        .map((p) => {
          const x = p as Record<string, unknown>;
          return `${x.name} بسعر ${money(x.price)} ليرة والمخزون ${x.stock}`;
        })
        .join('، ')}.`;
    case 'create_product': {
      const p = result as Record<string, unknown>;
      return `تمت إضافة المنتج ${p.name}.`;
    }
    case 'update_product_stock': {
      const p = result as Record<string, unknown>;
      return `تم تحديث المنتج ${p.name ?? args.productName}. المخزون ${p.stock} والسعر ${money(p.price)} ليرة.`;
    }
    case 'get_customer_invoices':
    case 'search_invoices':
    case 'get_latest_invoice': {
      const invoices = Array.isArray(result)
        ? result
        : result
          ? [result]
          : [];
      if (!invoices.length) return 'لا توجد فواتير مطابقة.';
      const first = invoices[0] as Record<string, unknown>;
      const cust =
        (first.customer as Record<string, unknown> | undefined)?.name ??
        args.customerName ??
        '';
      if (tool === 'get_latest_invoice') {
        return `آخر فاتورة رقم ${first.number} للعميل ${cust} بمبلغ ${money(first.total)} ليرة وحالتها ${first.status}.`;
      }
      const lines = invoices.slice(0, 8).map((inv) => {
        const x = inv as Record<string, unknown>;
        const cn =
          (x.customer as Record<string, unknown> | undefined)?.name ?? '';
        return `${x.number}${cn ? ' ل' + cn : ''} بمبلغ ${money(x.total)}`;
      });
      return `وجدت ${invoices.length} فاتورة: ${lines.join('، ')}.`;
    }
    case 'create_invoice': {
      const inv = result as Record<string, unknown>;
      return `تم إنشاء الفاتورة رقم ${inv.number} بمبلغ ${money(inv.total)} ليرة.`;
    }
    case 'update_invoice_status':
      return `تم تغيير حالة الفاتورة ${args.invoiceNumber} إلى ${args.status}.`;
    case 'generate_report': {
      const r = result as Record<string, unknown>;
      return `تقرير جاهز: ${r.count ?? 0} فاتورة بإجمالي ${money(r.totalAmount)} ليرة. يمكنك تنزيله من شاشة التقارير.`;
    }
    default:
      return 'تم تنفيذ الطلب.';
  }
}

/** Last-resort matcher when the LLM replies without a tool. */
export function matchLooseListIntent(message: string): MatchedIntent | null {
  const n = normalizeAr(message);
  if (!n || has(n, 'مرحبا', 'السلام', 'شكرا', 'اهلا')) return null;
  if (isCreate(n)) return null;
  if (has(n, 'عميل', 'عملا') && !talksInvoice(n)) {
    return { tool: 'list_customers', args: {} };
  }
  if (has(n, 'منتج') && !talksInvoice(n)) {
    return { tool: 'list_products', args: {} };
  }
  if (talksInvoice(n)) {
    return { tool: 'search_invoices', args: {} };
  }
  if (has(n, 'ملخص', 'احصائ')) {
    return { tool: 'get_accounting_summary', args: {} };
  }
  return null;
}
