#!/usr/bin/env python3
"""Generate Patroller macOS app icon - sleek squircle, lime field, black radar."""

from __future__ import annotations

import math
import struct
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]

# Brand lime sampled from reference logo
YELLOW = (227, 246, 7)
YELLOW_HI = (244, 255, 42)
YELLOW_LO = (198, 218, 0)
BLACK = (0, 0, 0)
INK = (8, 8, 10)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def lerp_rgb(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        int(lerp(c1[0], c2[0], t)),
        int(lerp(c1[1], c2[1], t)),
        int(lerp(c1[2], c2[2], t)),
    )


def squircle_mask(size: int) -> Image.Image:
    """macOS-style rounded square mask."""
    radius = int(size * 0.2237)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def ring_bbox(cx: float, cy: float, radius: float) -> tuple[float, float, float, float]:
    return (cx - radius, cy - radius, cx + radius, cy + radius)


def polar(cx: float, cy: float, radius: float, angle: float) -> tuple[float, float]:
    return (cx + math.cos(angle) * radius, cy + math.sin(angle) * radius)


def draw_background(size: int) -> Image.Image:
    """Premium radial field - stays in lime family, not amber."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx = cy = size / 2.0
    max_r = size * 0.72
    px = img.load()
    for y in range(size):
        for x in range(size):
            dx = x - cx
            dy = y - cy
            dist = math.sqrt(dx * dx + dy * dy) / max_r
            dist = min(dist, 1.0)
            # Brighter center, richer edge
            base = lerp_rgb(YELLOW_HI, YELLOW, dist * 0.55)
            edge = lerp_rgb(base, YELLOW_LO, max(0.0, (dist - 0.65) / 0.35))
            # Subtle top-left light
            light = max(0.0, 1.0 - ((x / size) * 0.35 + (y / size) * 0.15))
            final = lerp_rgb(edge, YELLOW_HI, light * 0.18)
            px[x, y] = (*final, 255)
    return img


def draw_gloss(size: int) -> Image.Image:
    gloss = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(gloss)
    cx = size / 2
    draw.ellipse(
        (size * 0.08, size * 0.02, size * 0.92, size * 0.58),
        fill=(255, 255, 255, 38),
    )
    draw.ellipse(
        (size * 0.22, size * 0.06, size * 0.72, size * 0.34),
        fill=(255, 255, 255, 22),
    )
    return gloss.filter(ImageFilter.GaussianBlur(radius=size * 0.02))


def draw_emblem(size: int) -> Image.Image:
    """Black radar mark - bold, centered, readable at 16px."""
    scale = size / 1024.0
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    cx = cy = size / 2.0
    outer_r = 318 * scale
    outer_w = max(2, int(44 * scale))
    ring_w = max(1, int(14 * scale))

    # Soft emblem shadow for depth
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.ellipse(
        ring_bbox(cx, cy + 6 * scale, outer_r + 8 * scale),
        fill=(0, 0, 0, 55),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=10 * scale))
    layer = Image.alpha_composite(layer, shadow)
    draw = ImageDraw.Draw(layer)

    # Outer command ring
    draw.ellipse(ring_bbox(cx, cy, outer_r), outline=BLACK, width=outer_w)

    # Precision rings
    for ratio in (0.78, 0.56, 0.34):
        r = outer_r * ratio
        draw.ellipse(ring_bbox(cx, cy, r), outline=BLACK, width=ring_w)

    # Power sweep - sharper, more assertive
    sweep_angle = math.radians(-32)
    spread = 0.19
    outer_edge = outer_r - outer_w * 0.15
    inner_hub = 28 * scale
    tip = polar(cx, cy, outer_edge, sweep_angle)
    outer_left = polar(cx, cy, outer_r + outer_w * 0.02, sweep_angle - spread)
    outer_right = polar(cx, cy, outer_r + outer_w * 0.02, sweep_angle + spread * 0.48)
    inner_left = polar(cx, cy, inner_hub, sweep_angle - spread * 0.32)
    inner_right = polar(cx, cy, inner_hub, sweep_angle + spread * 0.18)
    draw.polygon([tip, outer_left, outer_right, inner_right, inner_left], fill=BLACK)

    # Contact blips
    dot_r = max(2, int(13 * scale))
    blip_r = outer_r * 0.78
    for deg in (208, 252, 14):
        dx, dy = polar(cx, cy, blip_r, math.radians(deg))
        draw.ellipse((dx - dot_r, dy - dot_r, dx + dot_r, dy + dot_r), fill=BLACK)

    # Core hub
    hub_r = max(2, int(16 * scale))
    draw.ellipse((cx - hub_r, cy - hub_r, cx + hub_r, cy + hub_r), fill=BLACK)

    return layer


def draw_rim(size: int) -> Image.Image:
    """Subtle squircle edge definition."""
    rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(rim)
    radius = int(size * 0.2237)
    inset = max(1, int(size * 0.006))
    draw.rounded_rectangle(
        (inset, inset, size - inset, size - inset),
        radius=radius,
        outline=(0, 0, 0, 28),
        width=max(1, int(size * 0.008)),
    )
    draw.rounded_rectangle(
        (inset * 3, inset * 3, size - inset * 3, size - inset * 3),
        radius=radius,
        outline=(255, 255, 255, 24),
        width=max(1, int(size * 0.004)),
    )
    return rim


def render_icon(size: int) -> Image.Image:
    bg = draw_background(size)
    emblem = draw_emblem(size)
    gloss = draw_gloss(size)
    rim = draw_rim(size)

    composed = Image.alpha_composite(bg, emblem)
    composed = Image.alpha_composite(composed, gloss)
    composed = Image.alpha_composite(composed, rim)

    mask = squircle_mask(size)
    composed.putalpha(mask)
    return composed.convert("RGB")


def write_ico(images: list[tuple[int, Image.Image]], path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    entries = []
    image_data = b""
    offset = 6 + 16 * len(images)

    for size, img in images:
        if img.size != (size, size):
            img = img.resize((size, size), Image.Resampling.LANCZOS)
        rgba = img.convert("RGBA")
        w, h = rgba.size
        raw = rgba.tobytes()
        and_row = ((w + 31) // 32) * 4
        bmp = b""
        for y in range(h - 1, -1, -1):
            row_bytes = bytearray()
            for x in range(w):
                r, g, b, a = raw[(y * w + x) * 4 : (y * w + x) * 4 + 4]
                row_bytes.extend([b, g, r, a])
            bmp += bytes(row_bytes)
        bmp += b"\x00" * (and_row * h)
        entries.append((w, h, offset, len(bmp)))
        image_data += bmp
        offset += len(bmp)

    header = struct.pack("<HHH", 0, 1, len(images))
    directory = b""
    for w, h, off, sz in entries:
        directory += struct.pack(
            "<BBBBHHII",
            w if w < 256 else 0,
            h if h < 256 else 0,
            0,
            0,
            1,
            32,
            sz,
            off,
        )
    path.write_bytes(header + directory + image_data)


def export_size(master: Image.Image, dim: int) -> Image.Image:
    if dim >= 256:
        return master.resize((dim, dim), Image.Resampling.LANCZOS)
    # Supersample small icons for crisp strokes
    big = master.resize((dim * 4, dim * 4), Image.Resampling.LANCZOS)
    return big.resize((dim, dim), Image.Resampling.LANCZOS)


def main():
    master = render_icon(1024)

    targets = {
        ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png": 1024,
        ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png": 512,
        ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png": 256,
        ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png": 128,
        ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png": 64,
        ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png": 32,
        ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png": 16,
        ROOT / "assets/branding/patroller-app-icon.jpg": 1024,
    }

    for path, dim in targets.items():
        icon = export_size(master, dim)
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.suffix.lower() == ".jpg":
            icon.save(path, format="JPEG", quality=95)
        else:
            icon.save(path, format="PNG")

    ico_sizes = [16, 32, 48, 64, 128, 256]
    write_ico(
        [(s, export_size(master, s)) for s in ico_sizes],
        ROOT / "windows/runner/resources/app_icon.ico",
    )

    import shutil

    iconset = ROOT / "build/icon.iconset"
    if iconset.exists():
        shutil.rmtree(iconset)
    iconset.mkdir(parents=True)
    icns_map = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for name, dim in icns_map.items():
        export_size(master, dim).save(iconset / name, format="PNG")

    icns_out = ROOT / "build/Patroller.icns"
    try:
        subprocess.run(
            ["iconutil", "-c", "icns", str(iconset), "-o", str(icns_out)],
            check=True,
            capture_output=True,
        )
        print(f"✓ {icns_out}")
    except (FileNotFoundError, subprocess.CalledProcessError) as e:
        print(f"iconutil skipped: {e}")

    print("✓ Generated sleek macOS Patroller icon")


if __name__ == "__main__":
    main()