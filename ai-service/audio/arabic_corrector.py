"""Fix common Arabic STT mistakes for accounting commands."""

from __future__ import annotations

import re

_REPLACEMENTS: list[tuple[str, str]] = [
    (r"فاتو[رهاه]+", "فاتورة"),
    (r"فواتيره", "فواتير"),
    (r"العملا", "العملاء"),
    (r"منتجاات", "منتجات"),
    (r"محاسبه", "محاسبة"),
    (r"معلقه", "معلقة"),
    (r"مدفوعه", "مدفوعة"),
    (r"ملغاه", "ملغاة"),
    (r"مسوده", "مسودة"),
    (r"تقريرا", "تقريراً"),
    (r"اضف", "أضف"),
    (r"انشئ", "أنشئ"),
    (r"غير\s*حال[هة]", "غيّر حالة"),
    (r"الذكا\s*الاصطناعي", "الذكاء الاصطناعي"),
]


def _strip_diacritics(text: str) -> str:
    return re.sub(r"[\u064B-\u0652]", "", text)


def correct_arabic(text: str) -> str:
    if not text:
        return text

    out = _strip_diacritics(text.strip())
    out = out.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
    # restore hamza on common verbs after normalize
    for pat, repl in _REPLACEMENTS:
        out = re.sub(pat, repl, out, flags=re.IGNORECASE)

    # Eastern Arabic digits → Western
    trans = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")
    out = out.translate(trans)

    out = re.sub(r"\s+", " ", out).strip()

    # Restore alef-hamza on command verbs
    out = re.sub(r"^اضف\b", "أضف", out)
    out = re.sub(r"^انشئ\b", "أنشئ", out)
    out = re.sub(r"^اعرض\b", "اعرض", out)
    return out
