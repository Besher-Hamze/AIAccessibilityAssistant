"""Run from ai-service: .venv\\Scripts\\python -m unittest discover tests"""

import unittest

from audio.pipeline import is_hallucination


class HallucinationTest(unittest.TestCase):
    def test_prompt_echo_from_device_screenshot(self):
        self.assertTrue(
            is_hallucination(
                "اعرض المنتجات، ملخص المحاسبة، ملخص المحاسبة، تقرير الفواتير "
                "المعلقة والمدفوعة، ملخص المحاسبة، تقرير الفواتير المعلقة والمدفوعة"
            )
        )

    def test_looping_phrase(self):
        self.assertTrue(is_hallucination("شكرا لكم شكرا لكم شكرا لكم شكرا لكم"))

    def test_real_commands_pass(self):
        for text in (
            "افتح العملاء",
            "اعرض الفواتير المعلقة",
            "ما ملخص المحاسبة",
            "افتح الفواتير المدفوعة وانزل للاخير",
            "أضف عميل اسمه سارة ورقمها 0944001122",
            "أنشئ فاتورة لمحمد الأحمد بمنتج برنامج محاسبة كمية اثنين",
            "اعرض كل الفواتير المعلقة والمدفوعة للعميل خالد الدمشقي من الشهر الماضي",
        ):
            self.assertFalse(is_hallucination(text), text)


if __name__ == "__main__":
    unittest.main()
