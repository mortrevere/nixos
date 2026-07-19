#!/usr/bin/env python3
"""
paste-horizon: reads a file and autotypes its content after a delay.
Intended for sending passwords or text to remote VMs via ydotool (uinput),
for cases where clipboard paste is unavailable.

Usage: paste-horizon <file>

ydotool injects events via /dev/uinput, presenting as a real input device.
This bypasses Wayland's virtual-keyboard/IME layer, which tends to survive
RDP/VDI keyboard redirection (e.g. Omnissa Horizon) better than wtype does.
Requires ydotoold running (see programs.ydotool in NixOS config) and the
user to be in the "ydotool" group.

Remapping:
  REMAP maps source characters to replacement strings.
  Useful when the remote VM has a different keyboard layout (e.g. AZERTY host
  typing into a QWERTY VM via VNC/SPICE). Each value is typed literally by
  ydotool in place of the source character.

  Example (AZERTY → QWERTY VM):
    REMAP = {
        "@": "2",   # '@' on AZERTY sends keycode that VM reads as '2'
        "&": "1",
        "é": "2",
    }
"""

import subprocess
import sys
import time

# ---------------------------------------------------------------------------
# Remapping config — edit to match your remote VM's keyboard layout.
# Key   = character as it appears in your secret file (the desired output).
# Value = string that the backend should actually send so the VM produces
#         the intended key.
#
# ydotool sends keystrokes using *physical key positions* labeled per a
# US/QWERTY layout, regardless of the host's actual layout. If the remote
# guest's keyboard layout is French AZERTY (common case: AZERTY host +
# AZERTY guest, e.g. over Omnissa Horizon/RDP), the guest reinterprets those
# QWERTY-labeled physical keys through its own AZERTY keymap, so
# letters/digits/punctuation that differ in position between the two layouts
# come out wrong (e.g. sending "5" presses the physical key AZERTY reads as
# "(", sending "W"/"Z" swap, "," and ";" swap, etc).
#
# The table below is the inverse mapping: for each character you actually
# want to appear on an AZERTY guest, it gives the QWERTY-labeled character to
# send instead, so the same physical key/shift-state combination lines up.
# Clear this dict (or override entries) if your guest uses a different
# layout.
# ---------------------------------------------------------------------------
REMAP: dict = {
    # letters swapped between AZERTY and QWERTY (same physical key)
    "a": "q",
    "A": "Q",
    "q": "a",
    "Q": "A",
    "w": "z",
    "W": "Z",
    "z": "w",
    "Z": "W",
    # punctuation swapped (m / , / ;)
    "m": ";",
    "M": ":",
    ",": "m",
    "?": "M",
    ";": ",",
    ".": "<",
    ":": ".",
    "!": "/",
    "/": ">",
    "ù": "'",
    "%": '"',
    # number row: AZERTY needs Shift for digits, and has different unshifted
    # symbols (accented letters / punctuation) on the same physical keys
    "1": "!",
    "2": "@",
    "3": "#",
    "4": "$",
    "5": "%",
    "6": "^",
    "7": "&",
    "8": "*",
    "9": "(",
    "0": ")",
    "&": "1",
    "é": "2",
    '"': "3",
    "'": "4",
    "(": "5",
    "-": "6",
    "è": "7",
    "_": "8",
    "ç": "9",
    "à": "0",
    ")": "-",
}

DELAY_SECONDS = 2


def type_text(text: str) -> None:
    """Type text via ydotool, applying REMAP substitutions character by
    character."""
    buffer = ""
    for ch in text:
        if ch in REMAP:
            if buffer:
                subprocess.run(["ydotool", "type", "--", buffer], check=True)
                buffer = ""
            replacement = REMAP[ch]
            if replacement:
                subprocess.run(["ydotool", "type", "--", replacement], check=True)
        else:
            buffer += ch
    if buffer:
        subprocess.run(["ydotool", "type", "--", buffer], check=True)


def main() -> None:
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <file>", file=sys.stderr)
        sys.exit(1)

    filepath = sys.argv[1]
    try:
        with open(filepath) as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Error: file not found: {filepath}", file=sys.stderr)
        sys.exit(1)
    except PermissionError:
        print(f"Error: permission denied: {filepath}", file=sys.stderr)
        sys.exit(1)

    print(
        f"paste-horizon: typing in {DELAY_SECONDS}s — focus your target window now.",
        file=sys.stderr,
    )
    time.sleep(DELAY_SECONDS)
    type_text(content)


if __name__ == "__main__":
    main()
