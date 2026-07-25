"""Tests for the privacy filters in import_wispr_dictionary.py."""

import unittest

from import_wispr_dictionary import is_safe_term


class SafeTermTests(unittest.TestCase):
    def test_accepts_indian_names_and_music_terms(self) -> None:
        self.assertTrue(is_safe_term("Inchara"))
        self.assertTrue(is_safe_term("Nathaniel School of Music"))
        self.assertTrue(is_safe_term("Melakarta"))

    def test_rejects_contact_details_and_long_messages(self) -> None:
        self.assertFalse(is_safe_term("employee@example.com"))
        self.assertFalse(is_safe_term("https://example.com/private"))
        self.assertFalse(is_safe_term("+919876543210"))
        self.assertFalse(
            is_safe_term(
                "This is a complete private message that should not be imported"
            )
        )


if __name__ == "__main__":
    unittest.main()
