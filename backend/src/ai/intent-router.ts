/**
 * Deterministic Arabic voice-command matcher.
 * Handles common accounting phrases without waiting for the LLM.
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
  cancelled: 'CANCELLED',
  paid: 'PAID',
  pending: 'PENDING',
  draft: 'DRAFT',
};

export function normalizeAr(text: string): string {
  return text
    .replace(/[\u064B-\u0652]/g, '')
    .replace(/[إأآا]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
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

export function matchIntent(message: string): MatchedIntent | null {
  const raw = message.trim();
  const n = normalizeAr(raw);

  if (
    /ملخص/.test(n) ||
    /كم\s*الفواتير/.test(n) ||
    /اجمالي/.test(n) ||
    /حال[هة]\s*المحاسبه/.test(n)
  ) {
    return { tool: 'get_accounting_summary', args: {} };
  }

  if (/عرض\s*(قائمه\s*)?المنتجات|شو?\s*المنتجات|المنتجات/.test(n) && !/فاتور/.test(n)) {
    const search = after(raw, /منتج(?:ات)?\s+(?:اسمه|اسمها)?\s*(.+)$/i);
    return { tool: 'list_products', args: search ? { search } : {} };
  }

  if (/تقرير/.test(n)) {
    const status = pickStatus(raw);
    const customerName = after(raw, /(?:لفواتير|لعميل|للعميل)\s+(.+)$/i);
    const args: Record<string, unknown> = {};
    if (status) args.status = status;
    if (customerName) args.customerName = customerName.replace(/المعلق.*$/, '').trim();
    return { tool: 'generate_report', args };
  }

  if (/اخر\s*فاتور/.test(n)) {
    const customerName = after(raw, /(?:ل|للعميل|عميل)\s*(.+)$/i);
    return {
      tool: 'get_latest_invoice',
      args: customerName ? { customerName } : {},
    };
  }

  if (/غير|حدث|حول/.test(n) && /فاتور/.test(n) && /حال/.test(n)) {
    const invoiceNumber =
      after(raw, /(INV[-_][A-Za-z0-9-]+)/i) ||
      after(n, /فاتور(?:ه|ة)?\s+([A-Za-z0-9-_]+)/i);
    const status = pickStatus(raw);
    if (invoiceNumber && status) {
      return {
        tool: 'update_invoice_status',
        args: { invoiceNumber: invoiceNumber.toUpperCase(), status },
      };
    }
  }

  if (/اضف\s*عميل|عميل\s*جديد|سجل\s*عميل/.test(n)) {
    const name =
      after(raw, /(?:اسمه|اسمها|اسم)\s+(.+?)(?:\s+و?(?:رقم|هاتف|جوال)|$)/) ||
      after(raw, /عميل\s+(.+?)(?:\s+و?(?:رقم|هاتف|جوال)|$)/);
    const phone = after(raw, /(?:رقم(?:ها|ه)?|هاتف|جوال)\s*([0-9]{7,})/);
    if (name) {
      return {
        tool: 'create_customer',
        args: { name: name.trim(), ...(phone ? { phone } : {}) },
      };
    }
  }

  if (/بحث|ابحث/.test(n) && /عميل/.test(n)) {
    const query =
      after(raw, /(?:العميل|عميل)\s+(.+)$/) || after(raw, /عن\s+(.+)$/);
    return { tool: 'search_customers', args: { query: query || raw } };
  }

  if (/فاتور/.test(n) && !/انشئ|اضف|غير/.test(n)) {
    const status = pickStatus(raw);
    const customerName =
      after(raw, /(?:فواتير|فاتورة)\s+(.+)$/) ||
      after(raw, /(?:للعميل|ل)\s+(.+)$/);
    const args: Record<string, unknown> = {};
    if (status) args.status = status;
    if (customerName && !STATUS_MAP[normalizeAr(customerName)]) {
      args.customerName = customerName.replace(/المعلق.*|المدفوع.*|الشهر.*$/, '').trim();
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

  if (/انشئ\s*فاتور|فاتور(?:ه|ة)\s*جديد|اضف\s*فاتور/.test(n)) {
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

  if (/اضف\s*منتج|منتج\s*جديد/.test(n)) {
    const name = after(raw, /(?:اسمه|اسمها|اسم)\s+(.+?)(?:\s+سعر|$)/);
    const price = after(n, /سعر(?:ه|ها)?\s*([0-9]+)/);
    if (name && price) {
      return {
        tool: 'create_product',
        args: { name: name.trim(), price: Number(price) },
      };
    }
  }

  return null;
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
        `المدفوع ${s.paidAmount ?? 0} ليرة (${s.paidCount ?? 0})، ` +
        `والمعلق ${s.pendingAmount ?? 0} ليرة (${s.pendingCount ?? 0}).`
      );
    }
    case 'list_products':
      if (!list.length) return 'لا توجد منتجات مطابقة.';
      return `المنتجات: ${list
        .slice(0, 8)
        .map((p) => {
          const x = p as Record<string, unknown>;
          return `${x.name} بسعر ${x.price} ليرة والمخزون ${x.stock}`;
        })
        .join('، ')}.`;
    case 'search_customers':
    case 'create_customer': {
      if (!Array.isArray(result)) {
        const c = result as Record<string, unknown>;
        return `تمت إضافة العميل ${c.name ?? args.name}.`;
      }
      if (!list.length) return 'لم أجد عملاء مطابقين.';
      return `العملاء: ${list.map((c) => (c as Record<string, unknown>).name).join('، ')}.`;
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
      if (tool === 'get_latest_invoice') {
        return `آخر فاتورة رقم ${first.number} للعميل ${
          (first.customer as Record<string, unknown> | undefined)?.name ??
          args.customerName ??
          ''
        } بمبلغ ${first.total} ليرة وحالتها ${first.status}.`;
      }
      return `وجدت ${invoices.length} فاتورة. الأولى رقم ${first.number} بمبلغ ${first.total} ليرة.`;
    }
    case 'create_invoice': {
      const inv = result as Record<string, unknown>;
      return `تم إنشاء الفاتورة رقم ${inv.number} بمبلغ ${inv.total} ليرة.`;
    }
    case 'update_invoice_status':
      return `تم تغيير حالة الفاتورة ${args.invoiceNumber} إلى ${args.status}.`;
    case 'generate_report': {
      const r = result as Record<string, unknown>;
      return `تقرير جاهز: ${r.count ?? 0} فاتورة بإجمالي ${r.totalAmount ?? 0} ليرة. يمكنك تنزيله من شاشة التقارير.`;
    }
    case 'create_product': {
      const p = result as Record<string, unknown>;
      return `تمت إضافة المنتج ${p.name}.`;
    }
    default:
      return 'تم تنفيذ الطلب.';
  }
}
