#!/usr/bin/env python3
"""3-finger horizontal touchpad swipe → horizontal scroll.

Reads touchpad events via evdev, detects 3-finger horizontal swipes,
and emits REL_HWHEEL / REL_HWHEEL_HI_RES events through a virtual
UInput device.  Runs as a background daemon on Hyprland startup.

Adjust SCROLL_DIVISOR below to change sensitivity (lower = faster scroll).
"""

import signal
import sys

import evdev
from evdev import UInput, ecodes


# How many units of ABS_X movement per one REL_HWHEEL step.
# Touchpads typically report ABS_X in the range 0-4000+.
# Lower value = more sensitive scrolling.
SCROLL_DIVISOR = 60

# High-res scroll multiplier (REL_HWHEEL_HI_RES uses 120 units per notch).
HIRES_PER_NOTCH = 120


def find_touchpad():
    """Return the first touchpad InputDevice, or None."""
    for path in evdev.list_devices():
        dev = evdev.InputDevice(path)
        caps = dev.capabilities(absinfo=False)
        abs_caps = caps.get(ecodes.EV_ABS, [])
        key_caps = caps.get(ecodes.EV_KEY, [])
        if ecodes.ABS_MT_POSITION_X in abs_caps and ecodes.BTN_TOOL_FINGER in key_caps:
            return dev
    return None


def main():
    dev = find_touchpad()
    if dev is None:
        print("touchpad-hscroll: no touchpad found", file=sys.stderr)
        sys.exit(1)

    print(f"touchpad-hscroll: using {dev.name} ({dev.path})", file=sys.stderr)

    ui = UInput(
        {ecodes.EV_REL: [ecodes.REL_HWHEEL, ecodes.REL_HWHEEL_HI_RES]},
        name="touchpad-hscroll",
    )

    three_fingers = False
    prev_x = None
    accum = 0.0  # sub-notch accumulator for low-res REL_HWHEEL

    def cleanup(*_args):
        ui.close()
        sys.exit(0)

    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)

    for event in dev.read_loop():
        if event.type == ecodes.EV_KEY:
            if event.code == ecodes.BTN_TOOL_TRIPLETAP:
                three_fingers = event.value == 1
                if not three_fingers:
                    prev_x = None
                    accum = 0.0

        elif event.type == ecodes.EV_ABS and three_fingers:
            if event.code == ecodes.ABS_X:
                if prev_x is not None:
                    dx = event.value - prev_x

                    # High-res scroll (smooth in supporting apps)
                    hires = int(dx * HIRES_PER_NOTCH / SCROLL_DIVISOR)
                    if hires != 0:
                        ui.write(ecodes.EV_REL, ecodes.REL_HWHEEL_HI_RES, hires)

                    # Low-res scroll (compatibility fallback)
                    accum += dx / SCROLL_DIVISOR
                    notches = int(accum)
                    if notches != 0:
                        ui.write(ecodes.EV_REL, ecodes.REL_HWHEEL, notches)
                        accum -= notches

                    if hires != 0 or notches != 0:
                        ui.syn()

                prev_x = event.value


if __name__ == "__main__":
    main()
