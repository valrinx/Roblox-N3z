#!/usr/bin/env python3
import unittest
from pathlib import Path

from protect_all import AUTO_THRESHOLD_KIB, choose_profile


class AutoProfileTests(unittest.TestCase):
    def setUp(self):
        self.threshold = AUTO_THRESHOLD_KIB * 1024

    def test_control_plane_is_forced_max(self):
        for name in ("init.lua", "n3z.lua", "n3z-compat.lua"):
            with self.subTest(name=name):
                self.assertEqual(
                    choose_profile(Path(name), 200_000, "auto", self.threshold),
                    "max",
                )

    def test_dock_is_forced_performance(self):
        self.assertEqual(
            choose_profile(Path("n3z-dock.lua"), 1_000, "auto", self.threshold),
            "performance",
        )

    def test_modules_follow_size_threshold(self):
        self.assertEqual(
            choose_profile(
                Path("modules/small.lua"),
                self.threshold,
                "auto",
                self.threshold,
            ),
            "max",
        )
        self.assertEqual(
            choose_profile(
                Path("modules/large.lua"),
                self.threshold + 1,
                "auto",
                self.threshold,
            ),
            "performance",
        )

    def test_explicit_profile_wins(self):
        self.assertEqual(
            choose_profile(Path("n3z.lua"), 1, "performance", self.threshold),
            "performance",
        )
        self.assertEqual(
            choose_profile(Path("n3z-dock.lua"), 999_999, "max", self.threshold),
            "max",
        )


if __name__ == "__main__":
    unittest.main()
