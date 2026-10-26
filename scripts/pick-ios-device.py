#!/usr/bin/env python3
"""List or pick connected physical iOS devices for play-ios-device.sh."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass


@dataclass(frozen=True)
class Device:
    name: str
    udid: str
    transport: str

    @property
    def is_iphone(self) -> bool:
        return "iPhone" in self.name

    @property
    def is_ipad(self) -> bool:
        return "iPad" in self.name

    @property
    def is_duo(self) -> bool:
        return "iPhone Duo" in self.name


def load_devices(json_path: str | None = None) -> list[Device]:
    if json_path:
        payload = json.loads(open(json_path, encoding="utf-8").read())
    else:
        completed = subprocess.run(
            ["xcrun", "devicectl", "list", "devices", "--json-output", "-"],
            check=True,
            capture_output=True,
            text=True,
        )
        payload = json.loads(completed.stdout)

    devices: list[Device] = []
    for entry in payload.get("result", {}).get("devices") or []:
        hardware = entry.get("hardwareProperties") or {}
        props = entry.get("deviceProperties") or {}
        connection = entry.get("connectionProperties") or {}
        if hardware.get("reality") != "physical" or hardware.get("platform") != "iOS":
            continue
        if connection.get("tunnelState") == "unavailable":
            continue
        transport = connection.get("transportType")
        if not transport or transport == "sameMachine":
            continue
        udid = hardware.get("udid")
        if not udid:
            continue
        name = props.get("name") or hardware.get("marketingName") or udid
        devices.append(Device(name=name, udid=udid, transport=transport))
    return devices


def transport_rank(transport: str) -> int:
    return 0 if transport in ("wired", "local") else 1


def name_rank(device: Device, target: str) -> int:
    if target == "iphone":
        if device.is_duo:
            return 0
        if "iPhone Air" in device.name:
            return 1
        if device.is_iphone:
            return 2
        if device.is_ipad:
            return 10
        return 5
    if target == "ipad":
        if "iPad Pro" in device.name:
            return 0
        if device.is_ipad:
            return 1
        if device.is_iphone:
            return 10
        return 5
    # auto: prefer iPhone Duo, then iPhone Air, other iPhones, and iPads.
    if device.is_duo:
        return 0
    if "iPhone Air" in device.name:
        return 1
    if device.is_iphone:
        return 2
    if device.is_ipad:
        return 3
    return 4


def filter_devices(devices: list[Device], target: str) -> list[Device]:
    if target == "all":
        return devices
    if target == "duo":
        return [device for device in devices if device.is_duo]
    if target == "iphone":
        filtered = [device for device in devices if device.is_iphone]
        return filtered or devices
    if target == "ipad":
        filtered = [device for device in devices if device.is_ipad]
        return filtered or devices
    return devices


def pick_devices(devices: list[Device], target: str) -> list[Device]:
    candidates = filter_devices(devices, target)
    if target == "all":
        return sorted(
            candidates,
            key=lambda device: (
                name_rank(device, "auto"),
                transport_rank(device.transport),
                device.name.lower(),
            ),
        )
    if not candidates:
        return []
    best = min(
        candidates,
        key=lambda device: (
            name_rank(device, target if target != "auto" else "auto"),
            transport_rank(device.transport),
            device.name.lower(),
        ),
    )
    return [best]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--target",
        choices=("auto", "duo", "iphone", "ipad", "all"),
        default="auto",
        help="Which connected device(s) to return (default: auto).",
    )
    parser.add_argument(
        "--json-input",
        metavar="PATH",
        help="Optional devicectl JSON file (for tests).",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="Print name and UDID for every connected physical iOS device.",
    )
    args = parser.parse_args()

    try:
        devices = load_devices(args.json_input)
    except (subprocess.CalledProcessError, json.JSONDecodeError, OSError) as exc:
        print(f"Failed to read connected devices: {exc}", file=sys.stderr)
        return 1

    if args.list:
        if not devices:
            print("No connected physical iOS devices were found.", file=sys.stderr)
            return 1
        for device in sorted(devices, key=lambda item: item.name.lower()):
            print(f"{device.name}\t{device.udid}\t{device.transport}")
        return 0

    selected = pick_devices(devices, args.target)
    if not selected:
        print("No connected physical iOS devices were found.", file=sys.stderr)
        return 1
    for device in selected:
        print(device.udid)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
