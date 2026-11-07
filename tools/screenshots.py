#!/usr/bin/env python3
"""Captures App Store screenshots in the iOS simulators, using showcase mode.

    cd vompt && flutter build ios --simulator --debug && cd ..
    python3 tools/screenshots.py            # all devices
    python3 tools/screenshots.py iphone-6.9 # one device

Each scene launches the app straight into a staged screen with demo content
(see vompt/lib/showcase.dart, debug builds only), so shots are identical on
every run. The scene name is passed in Documents/showcase.txt.
Output: store/screenshots/<device>/<n>-<scene>.png
"""
import json
import pathlib
import plistlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP = ROOT / "vompt/build/ios/iphonesimulator/Runner.app"
OUT = ROOT / "store/screenshots"

# App Store Connect sizes: 6.9" iPhone (1320 x 2868) and 13" iPad (2064 x 2752).
# Smaller devices are scaled from these by App Store Connect.
DEVICES = {
    "iphone-6.9": "iPhone 17 Pro Max",
    "ipad-13": "iPad Pro 13-inch (M5)",
}

# Degrees to turn the portrait framebuffer for landscape scenes. iPads that
# support multitasking can't force landscape, so the prompter there stays in
# portrait and needs no turn.
LANDSCAPE_TURN = {"iphone-6.9": 270, "ipad-13": 0}

# (file name, showcase scene, orientation)
SCENES = [
    ("1-prompter", "prompter", "landscape"),
    ("2-summary", "summary", "landscape"),
    ("3-library", "library", "portrait"),
    ("4-assist", "assist", "portrait"),
    ("5-history", "history", "portrait"),
    ("6-editor", "editor", "portrait"),
]


def run(*args, env=None, check=True):
    return subprocess.run(args, check=check, capture_output=True, text=True, env=env)


def find_device(name):
    devices = json.loads(run("xcrun", "simctl", "list", "devices", "available", "-j").stdout)["devices"]
    matches = []
    for runtime, entries in devices.items():
        if "iOS" not in runtime:
            continue
        version = tuple(int(p) for p in runtime.rsplit("iOS-", 1)[-1].split("-") if p.isdigit())
        matches += [(version, d["udid"]) for d in entries if d["name"] == name]
    if not matches:
        sys.exit(f"No simulator named {name!r}. Create one in Xcode > Window > Devices and Simulators.")
    return max(matches)[1]


def capture(device_key, name):
    udid = find_device(name)
    bundle = plistlib.loads((APP / "Info.plist").read_bytes())["CFBundleIdentifier"]
    run("xcrun", "simctl", "boot", udid, check=False)
    run("xcrun", "simctl", "bootstatus", udid, "-b")
    run("xcrun", "simctl", "status_bar", udid, "override", "--time", "9:41",
        "--dataNetwork", "wifi", "--wifiMode", "active", "--wifiBars", "3",
        "--cellularMode", "active", "--cellularBars", "4",
        "--batteryState", "charged", "--batteryLevel", "100")
    run("xcrun", "simctl", "install", udid, str(APP))
    folder = OUT / device_key
    folder.mkdir(parents=True, exist_ok=True)

    for i, (file_name, scene, orientation) in enumerate(SCENES):
        run("xcrun", "simctl", "terminate", udid, bundle, check=False)
        data = pathlib.Path(run("xcrun", "simctl", "get_app_container", udid, bundle, "data").stdout.strip())
        (data / "Documents").mkdir(parents=True, exist_ok=True)
        (data / "Documents/showcase.txt").write_text(scene)
        run("xcrun", "simctl", "launch", udid, bundle)
        # Debug builds start slowly the first time; staged screens settle after.
        time.sleep(14 if i == 0 else 9)
        path = folder / f"{file_name}.png"
        run("xcrun", "simctl", "io", udid, "screenshot", "--type=png", str(path))
        fix_orientation(path, orientation, LANDSCAPE_TURN[device_key])
        print(f"{device_key}: {path.relative_to(ROOT)}")

    run("xcrun", "simctl", "terminate", udid, bundle, check=False)
    (data / "Documents/showcase.txt").unlink(missing_ok=True)
    run("xcrun", "simctl", "status_bar", udid, "clear", check=False)


def fix_orientation(path, orientation, turn):
    """simctl captures the portrait framebuffer; turn landscape scenes upright."""
    info = run("sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)).stdout
    width = int(info.split("pixelWidth:")[1].split()[0])
    height = int(info.split("pixelHeight:")[1].split()[0])
    if turn and orientation == "landscape" and height > width:
        run("sips", "-r", str(turn), str(path))


if __name__ == "__main__":
    if not APP.exists():
        sys.exit("Build first: cd vompt && flutter build ios --simulator --debug")
    wanted = sys.argv[1:] or list(DEVICES)
    for key in wanted:
        capture(key, DEVICES[key])
