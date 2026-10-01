#!/usr/bin/env python3
import unittest

from obfuscator import (
    PROFILES,
    checksum,
    deobfuscation_roundtrip_for_test,
    obfuscate_code,
)


class ObfuscatorTests(unittest.TestCase):
    SAMPLE = """local x = 41
local function add(a, b)
    return a + b
end
return add(x, 1)
"""

    def test_roundtrip_all_profiles(self):
        for profile in PROFILES:
            with self.subTest(profile=profile):
                restored = deobfuscation_roundtrip_for_test(self.SAMPLE, profile, seed=1234)
                self.assertEqual(restored.decode("utf-8"), self.SAMPLE)

    def test_unicode_roundtrip(self):
        source = "local message = 'ทดสอบ N3Z ✓'\nreturn message\n"
        for profile in PROFILES:
            restored = deobfuscation_roundtrip_for_test(source, profile, seed=99)
            self.assertEqual(restored.decode("utf-8"), source)

    def test_build_diversification(self):
        first = obfuscate_code(self.SAMPLE, profile="performance", seed=1)
        second = obfuscate_code(self.SAMPLE, profile="performance", seed=2)
        self.assertNotEqual(first, second)
        self.assertIn("N3Z Shield v3.0", first)

    def test_profile_changes_shape(self):
        performance = obfuscate_code(self.SAMPLE * 30, profile="performance", seed=7)
        maximum = obfuscate_code(self.SAMPLE * 30, profile="max", seed=7)
        self.assertNotEqual(performance, maximum)
        self.assertIn("Profile: performance", performance)
        self.assertIn("Profile: max", maximum)

    def test_checksum_changes_on_tamper(self):
        raw = self.SAMPLE.encode("utf-8")
        changed = bytearray(raw)
        changed[len(changed) // 2] ^= 1
        self.assertNotEqual(checksum(raw), checksum(changed))


if __name__ == "__main__":
    unittest.main()
