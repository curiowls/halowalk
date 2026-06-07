#!/usr/bin/env python3
"""
Generate a placeholder app icon for the pilot — a sketch-style halo ring
on paper background. Replace with proper artwork before App Store
submission. Outputs Resources/AppIcon.appiconset/ ready for Xcode.
"""
import os, math, struct, zlib, json

OUT = os.path.join(os.path.dirname(__file__), "..", "Resources", "AppIcon.appiconset")
os.makedirs(OUT, exist_ok=True)

PAPER = (251, 248, 242)
INK = (26, 23, 20)
HALO_GREEN = (90, 157, 110)
HALO_PINK = (217, 159, 177)


def write_png(path, size, draw):
    """Write a square PNG of given size by calling draw(x, y) -> (r,g,b)."""
    raw = bytearray()
    for y in range(size):
        raw.append(0)  # filter byte: no filtering
        for x in range(size):
            r, g, b = draw(x, y)
            raw += bytes((r, g, b))
    # Build a minimal PNG
    def chunk(typ, data):
        crc = zlib.crc32(typ + data)
        return struct.pack(">I", len(data)) + typ + data + struct.pack(">I", crc)
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)  # 8-bit RGB
    idat = zlib.compress(bytes(raw), 9)
    with open(path, "wb") as f:
        f.write(sig)
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", idat))
        f.write(chunk(b"IEND", b""))


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def make_icon(size):
    """Draw the icon: paper background, dashed halo ring, small filled center,
    a soft pink glow inside. Resolution-independent."""
    cx = cy = size / 2
    outer_r = size * 0.36
    inner_r = size * 0.10
    glow_r = size * 0.30

    def draw(x, y):
        dx = x - cx
        dy = y - cy
        d = math.sqrt(dx * dx + dy * dy)
        # Soft pink glow
        if d < glow_r:
            t = d / glow_r
            return lerp(HALO_PINK, PAPER, min(1, t * 1.4))
        # Center dot
        if d < inner_r:
            return INK
        # Outer dashed ring (approximated by angular alternation)
        ring_thick = max(2, size * 0.012)
        if abs(d - outer_r) < ring_thick:
            angle = (math.atan2(dy, dx) + math.pi) / (2 * math.pi)
            seg = (angle * 24) % 1.0
            if seg < 0.6:
                return HALO_GREEN
        return PAPER

    return draw


sizes = [
    # iPhone
    (40, "20@2x"), (60, "20@3x"),
    (58, "29@2x"), (87, "29@3x"),
    (80, "40@2x"), (120, "40@3x"),
    (120, "60@2x"), (180, "60@3x"),
    # Marketing — App Store
    (1024, "1024"),
]

contents = {"images": [], "info": {"author": "xcode", "version": 1}}

# iPhone scaled icons
for size_px, suffix in sizes:
    if suffix == "1024":
        filename = f"AppIcon-1024.png"
        contents["images"].append({
            "size": "1024x1024",
            "idiom": "ios-marketing",
            "filename": filename,
            "scale": "1x",
        })
    else:
        base, scale = suffix.split("@") if "@" in suffix else (suffix, "1x")
        filename = f"AppIcon-{base}@{scale}.png"
        contents["images"].append({
            "size": f"{base}x{base}",
            "idiom": "iphone",
            "filename": filename,
            "scale": scale,
        })
    path = os.path.join(OUT, filename)
    print(f"  generating {filename} @ {size_px}px")
    write_png(path, size_px, make_icon(size_px))

with open(os.path.join(OUT, "Contents.json"), "w") as f:
    json.dump(contents, f, indent=2)

# Make the asset catalog wrapper if it doesn't exist
catalog_root = os.path.join(os.path.dirname(__file__), "..", "Resources", "Assets.xcassets")
os.makedirs(catalog_root, exist_ok=True)
catalog_contents = os.path.join(catalog_root, "Contents.json")
if not os.path.exists(catalog_contents):
    with open(catalog_contents, "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)

# Move appiconset into asset catalog
target_iconset = os.path.join(catalog_root, "AppIcon.appiconset")
if os.path.exists(target_iconset):
    import shutil
    shutil.rmtree(target_iconset)
import shutil
shutil.move(OUT, target_iconset)

print(f"\nWrote AppIcon.appiconset to {target_iconset}")
