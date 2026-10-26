#!/usr/bin/env python3
"""Unit tests for deterministic physical iOS device selection."""

from __future__ import annotations

import importlib.util
import pathlib
import sys
import unittest


SCRIPT = pathlib.Path(__file__).with_name("pick-ios-device.py")
SPEC = importlib.util.spec_from_file_location("pick_ios_device", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)

Device = MODULE.Device
pick_devices = MODULE.pick_devices


class DeviceSelectionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.duo = Device("CJ's iPhone Duo", "duo", "local")
        self.air = Device("CJ's iPhone Air", "air", "wired")
        self.iphone = Device("Test iPhone", "phone", "wired")
        self.ipad = Device("CJ's iPad Pro", "ipad", "wired")

    def test_auto_prefers_duo_even_when_air_is_wired(self) -> None:
        self.assertEqual(pick_devices([self.air, self.duo], "auto"), [self.duo])

    def test_iphone_prefers_duo_then_air(self) -> None:
        self.assertEqual(pick_devices([self.iphone, self.air, self.duo], "iphone"), [self.duo])
        self.assertEqual(pick_devices([self.iphone, self.air], "iphone"), [self.air])

    def test_duo_target_does_not_fall_back_to_another_iphone(self) -> None:
        self.assertEqual(pick_devices([self.air, self.iphone], "duo"), [])
        self.assertEqual(pick_devices([self.air, self.duo], "duo"), [self.duo])

    def test_ipad_target_keeps_ipad_preference(self) -> None:
        self.assertEqual(pick_devices([self.iphone, self.ipad], "ipad"), [self.ipad])


if __name__ == "__main__":
    unittest.main()
