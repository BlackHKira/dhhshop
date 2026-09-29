# Nén ảnh sản phẩm về <=25KB (JPEG) cho Firestore image_data.
# - Ảnh thật: resize cạnh dài 360px, binary-search quality 85->30 tới khi <=25KB.
# - Thiếu ảnh: sinh placeholder (nền màu theo danh mục + tên SP).
#
#   python scripts/compress_images.py
#
# Đọc:  temp\opencode\products.json  (slug, name, category)
#       temp\opencode\catalog_raw\<slug>.jpg
# Ghi:  temp\opencode\catalog_img\<slug>.jpg

import io
import json
import os
import textwrap

from PIL import Image, ImageDraw, ImageFont

RAW_DIR = r'C:\Users\black\AppData\Local\Temp\opencode\catalog_raw'
OUT_DIR = r'C:\Users\black\AppData\Local\Temp\opencode\catalog_img'
PRODUCTS_JSON = r'C:\Users\black\AppData\Local\Temp\opencode\products.json'

MAX_BYTES = 120000
MAX_SIDE = 600

CAT_COLORS = {
    'dien-thoai': (41, 128, 185),
    'laptop': (39, 174, 96),
    'may-tinh-bang': (142, 68, 173),
    'linh-kien-pc': (211, 84, 0),
    'pc-nguyen-bo': (192, 57, 43),
    'man-hinh': (22, 160, 133),
    'gaming-gear': (44, 62, 80),
    'am-thanh': (243, 156, 18),
    'camera': (127, 140, 141),
    'smartwatch': (26, 188, 156),
    'phu-kien': (149, 165, 166),
}

FONT_CANDIDATES = [
    r'C:\Windows\Fonts\segoeui.ttf',
    r'C:\Windows\Fonts\arial.ttf',
    r'C:\Windows\Fonts\calibri.ttf',
]


def load_font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                pass
    return ImageFont.load_default()


def compress_image(src, dst):
    img = Image.open(src).convert('RGB')
    img.thumbnail((MAX_SIDE, MAX_SIDE), Image.LANCZOS)
    for quality in range(90, 54, -4):
        buf = io.BytesIO()
        img.save(buf, 'JPEG', quality=quality, optimize=True, progressive=True)
        if buf.tell() <= MAX_BYTES:
            with open(dst, 'wb') as f:
                f.write(buf.getvalue())
            return buf.tell()
    # vẫn lớn -> nhỏ hơn
    img.thumbnail((420, 420), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, 'JPEG', quality=55, optimize=True, progressive=True)
    with open(dst, 'wb') as f:
        f.write(buf.getvalue())
    return buf.tell()


def make_placeholder(name, color, dst):
    img = Image.new('RGB', (MAX_SIDE, MAX_SIDE), color)
    draw = ImageDraw.Draw(img)
    # gradient nhẹ từ trên xuống
    for y in range(MAX_SIDE):
        factor = 1 - (y / MAX_SIDE) * 0.25
        row = tuple(int(c * factor) for c in color)
        draw.line([(0, y), (MAX_SIDE, y)], fill=row)

    font = load_font(22)
    lines = textwrap.wrap(name, width=22) or [name]
    line_h = 26
    total_h = line_h * len(lines)
    y = (MAX_SIDE - total_h) // 2
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        w = bbox[2] - bbox[0]
        draw.text(((MAX_SIDE - w) // 2, y), line, fill=(255, 255, 255), font=font)
        y += line_h

    buf = io.BytesIO()
    img.save(buf, 'JPEG', quality=70, optimize=True)
    with open(dst, 'wb') as f:
        f.write(buf.getvalue())
    return buf.tell()


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(PRODUCTS_JSON, encoding='utf-8') as f:
        data = json.load(f)
    products = data['products']

    ok = 0
    placeholder = 0
    fail = 0
    for p in products:
        slug = p['slug']
        dst = os.path.join(OUT_DIR, f'{slug}.jpg')
        src = os.path.join(RAW_DIR, f'{slug}.jpg')
        if os.path.exists(src):
            try:
                size = compress_image(src, dst)
                ok += 1
                print(f'OK   {slug} ({size}b)')
                continue
            except Exception as e:
                print(f'ERR  {slug}: {e}')
                fail += 1
        # thiếu ảnh -> placeholder
        color = CAT_COLORS.get(p['category'], (100, 100, 100))
        try:
            size = make_placeholder(p['name'], color, dst)
            placeholder += 1
            print(f'PH   {slug} ({size}b)')
        except Exception as e:
            print(f'FAIL {slug}: {e}')
            fail += 1

    print(f'\nXong: ok={ok} placeholder={placeholder} fail={fail}')


if __name__ == '__main__':
    main()
