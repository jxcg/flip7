#!/usr/bin/env python3
"""Generates and validates the Flip 7 value ramp.

Run it: `python3 docs/palette_check.py`. It prints the palette table used in
DESIGN_LANGUAGE.md and exits non-zero if any pair falls below its contrast
floor, so the ramp can never drift out of accessibility compliance unnoticed.
"""

import colorsys
import math
import sys

# Hue per card value. 0 is neutral (saturation 0). 1-12 rotate monotonically
# red -> magenta and deliberately skip 205-235 degrees, the lane reserved for
# the system-blue accent, so no card ever competes with an interactive control.
HUES = {
    0: None, 1: 8, 2: 26, 3: 42, 4: 55, 5: 78, 6: 105,
    7: 142, 8: 168, 9: 192, 10: 252, 11: 278, 12: 312,
}

TABLE_LIGHT = "#F2F2F7"  # systemGroupedBackground
TABLE_DARK = "#000000"   # true black, OLED

# WCAG AAA asks 4.5:1 of *large* text (>= 18pt regular / 14pt bold). The card
# numeral is 44pt SF Rounded Black, so 4.5 here is the AAA target correctly
# applied, not a relaxation of it. The earlier 7.0 was the normal-text figure,
# and it forced washes so pale that adjacent values were not tellable apart.
INK_ON_WASH_MIN = 4.5    # numeral on its own card (AAA, large text)
INK_INCREASE_CONTRAST = 7.0  # what Increase Contrast restores (see 3.4)
RAIL_ON_TABLE_MIN = 3.0  # non-text UI element
ADJACENT_WASH_MIN_DELTA_E = 5.0  # neighbouring values must be tellable apart


def hsl_hex(hue_degrees, saturation, lightness):
    if hue_degrees is None:
        saturation = 0.0
        hue_degrees = 0
    red, green, blue = colorsys.hls_to_rgb(hue_degrees / 360, lightness, saturation)
    return "#%02X%02X%02X" % (round(red * 255), round(green * 255), round(blue * 255))


def relative_luminance(hex_color):
    channels = [int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def contrast(foreground, background):
    lighter, darker = sorted(
        (relative_luminance(foreground), relative_luminance(background)), reverse=True
    )
    return (lighter + 0.05) / (darker + 0.05)


def solve(hue, saturation, background, floor, start, step):
    """Walks lightness away from `background` until the pair clears `floor`.

    Solving rather than hand-picking keeps all 52 generated colours consistent:
    each hue lands on the least extreme lightness that still passes, so the
    ramp stays as gentle as the contrast requirement allows.
    """
    lightness = start
    while 0.02 <= lightness <= 0.98:
        candidate = hsl_hex(hue, saturation, lightness)
        if contrast(candidate, background) >= floor:
            return candidate
        lightness += step
    raise AssertionError(f"no colour passes {floor}:1 for hue {hue} on {background}")


def srgb_to_lab(hex_color):
    """CIELAB conversion, needed because contrast ratio says nothing about hue.

    Two washes can both clear their contrast floor and still be the same colour
    to a player; only a perceptual distance metric catches that.
    """
    channels = [int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    red, green, blue = linear
    x = (0.4124 * red + 0.3576 * green + 0.1805 * blue) / 0.95047
    y = (0.2126 * red + 0.7152 * green + 0.0722 * blue)
    z = (0.0193 * red + 0.1192 * green + 0.9505 * blue) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 0.008856 else (7.787 * t + 16 / 116)
    fx, fy, fz = f(x), f(y), f(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def delta_e(first, second):
    """CIE76 distance. Below ~2.3 is imperceptible; above ~10 reads as a
    different colour without deliberate comparison."""
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(srgb_to_lab(first), srgb_to_lab(second))))


def build():
    rows = []
    for value, hue in HUES.items():
        wash_light = hsl_hex(hue, 0.72, 0.86)
        wash_dark = hsl_hex(hue, 0.55, 0.26)
        rows.append({
            "value": value,
            "hue": "neutral" if hue is None else f"{hue}",
            "wash_light": wash_light,
            "ink_light": solve(hue, 0.85, wash_light, INK_ON_WASH_MIN, 0.46, -0.01),
            "rail_light": solve(hue, 0.72, TABLE_LIGHT, RAIL_ON_TABLE_MIN, 0.48, -0.01),
            "wash_dark": wash_dark,
            "ink_dark": solve(hue, 0.90, wash_dark, INK_ON_WASH_MIN, 0.54, 0.01),
            "rail_dark": solve(hue, 0.75, TABLE_DARK, RAIL_ON_TABLE_MIN, 0.52, 0.01),
        })
    return rows


def main():
    rows = build()
    failures = []
    print("| Value | Hue | Wash (light) | Ink (light) | Ratio | \u0394E | Wash (dark) | Ink (dark) | Ratio | \u0394E | Rail L/D |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    for index, row in enumerate(rows):
        light_ratio = contrast(row["ink_light"], row["wash_light"])
        dark_ratio = contrast(row["ink_dark"], row["wash_dark"])
        rail_light_ratio = contrast(row["rail_light"], TABLE_LIGHT)
        rail_dark_ratio = contrast(row["rail_dark"], TABLE_DARK)
        previous = rows[index - 1] if index else None
        light_delta = delta_e(row["wash_light"], previous["wash_light"]) if previous else None
        dark_delta = delta_e(row["wash_dark"], previous["wash_dark"]) if previous else None

        checks = [
            (f"{row['value']} ink/wash light", light_ratio, INK_ON_WASH_MIN),
            (f"{row['value']} ink/wash dark", dark_ratio, INK_ON_WASH_MIN),
            (f"{row['value']} rail/table light", rail_light_ratio, RAIL_ON_TABLE_MIN),
            (f"{row['value']} rail/table dark", rail_dark_ratio, RAIL_ON_TABLE_MIN),
        ]
        if previous:
            checks += [
                (f"{previous['value']}->{row['value']} wash light dE", light_delta, ADJACENT_WASH_MIN_DELTA_E),
                (f"{previous['value']}->{row['value']} wash dark dE", dark_delta, ADJACENT_WASH_MIN_DELTA_E),
            ]
        for label, ratio, floor in checks:
            if ratio < floor:
                failures.append(f"{label}: {ratio:.2f} < {floor}")
        print(
            f"| {row['value']} | {row['hue']} | `{row['wash_light']}` | `{row['ink_light']}` "
            f"| {light_ratio:.1f} | {'-' if light_delta is None else format(light_delta, '.1f')} "
            f"| `{row['wash_dark']}` | `{row['ink_dark']}` | {dark_ratio:.1f} "
            f"| {'-' if dark_delta is None else format(dark_delta, '.1f')} "
            f"| `{row['rail_light']}` / `{row['rail_dark']}` |"
        )

    # Increase Contrast drops the washes entirely and falls back to system
    # surface + label, which must restore the stricter 7:1 the ramp gives up.
    for label, pair in (
        ("increase contrast light", ("#000000", "#FFFFFF")),
        ("increase contrast dark", ("#FFFFFF", "#1C1C1E")),
    ):
        ratio = contrast(*pair)
        if ratio < INK_INCREASE_CONTRAST:
            failures.append(f"{label}: {ratio:.2f} < {INK_INCREASE_CONTRAST}")

    if failures:
        print("\nFAIL:", *failures, sep="\n  ")
        sys.exit(1)
    checks = len(rows) * 4 + (len(rows) - 1) * 2 + 2
    print(f"\nOK: {checks} checks passed "
          f"(ink >= {INK_ON_WASH_MIN}:1, rail >= {RAIL_ON_TABLE_MIN}:1, "
          f"adjacent wash dE >= {ADJACENT_WASH_MIN_DELTA_E}).")


if __name__ == "__main__":
    main()
