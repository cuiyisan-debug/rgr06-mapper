from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "rgr06-pc-mapping.png"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        r"C:\Windows\Fonts\Noto Sans SC Bold (TrueType).otf" if bold else r"C:\Windows\Fonts\Noto Sans SC (TrueType).otf",
        r"C:\Windows\Fonts\msyhbd.ttc" if bold else r"C:\Windows\Fonts\msyh.ttc",
        r"C:\Windows\Fonts\simhei.ttf",
    ]
    for item in candidates:
        if item and Path(item).exists():
            return ImageFont.truetype(item, size)
    return ImageFont.load_default()


def draw_ring(canvas: Image.Image) -> None:
    product = Image.new("RGBA", (420, 460), (255, 255, 255, 0))
    draw = ImageDraw.Draw(product)

    shadow = Image.new("RGBA", (420, 460), (255, 255, 255, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse((160, 220, 330, 420), fill=(0, 0, 0, 70))
    sd.rounded_rectangle((115, 72, 325, 310), radius=72, fill=(0, 0, 0, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    product.alpha_composite(shadow)

    # Ring loop.
    draw.ellipse((170, 210, 330, 410), fill=(22, 24, 27), outline=(72, 76, 82), width=4)
    draw.ellipse((202, 255, 298, 382), fill=(255, 255, 255, 0), outline=(9, 10, 12), width=30)

    # Main black body.
    draw.rounded_rectangle((120, 78, 330, 316), radius=72, fill=(28, 30, 34), outline=(64, 68, 74), width=3)
    draw.rounded_rectangle((135, 88, 312, 296), radius=58, fill=(42, 45, 50))

    # Silver touch panel.
    draw.rounded_rectangle((76, 114, 220, 322), radius=32, fill=(182, 184, 184), outline=(112, 116, 120), width=3)
    draw.rounded_rectangle((96, 128, 198, 306), radius=24, fill=(208, 210, 210))

    # Top wheel and side buttons.
    draw.rounded_rectangle((188, 58, 236, 138), radius=18, fill=(20, 21, 23), outline=(70, 74, 78), width=2)
    for y in range(67, 132, 10):
        draw.line((198, y, 228, y + 7), fill=(90, 94, 98), width=2)
    draw.ellipse((292, 128, 314, 150), fill=(224, 42, 42))
    draw.ellipse((282, 222, 297, 237), fill=(0, 111, 255))
    draw.ellipse((126, 270, 140, 284), fill=(224, 42, 42))

    product = product.rotate(-12, resample=Image.Resampling.BICUBIC, expand=True)
    canvas.alpha_composite(product, (458, 198))


def draw_multiline(draw: ImageDraw.ImageDraw, xy, lines, fill, fnt, line_gap=8):
    x, y = xy
    for text in lines:
        draw.text((x, y), text, fill=fill, font=fnt)
        y += fnt.size + line_gap


def callout(draw: ImageDraw.ImageDraw, start, end):
    red = (214, 48, 49)
    draw.line((start, end), fill=red, width=3)
    r = 5
    draw.ellipse((end[0] - r, end[1] - r, end[0] + r, end[1] + r), fill=red)


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas = Image.new("RGBA", (1280, 820), (255, 255, 255, 255))
    draw = ImageDraw.Draw(canvas)

    title_font = font(42, True)
    label_font = font(28)
    small_font = font(22)
    footer_font = font(24)
    black = (31, 35, 40)
    muted = (86, 94, 104)
    red = (214, 48, 49)

    draw.text((72, 42), "RGR06 Mapper 电脑端鼠标控制映射", fill=black, font=title_font)
    draw.text((76, 100), "乐奇眼镜配套 RGR06 戒指，改作 Windows 电脑鼠标与快捷键控制", fill=muted, font=small_font)

    draw_ring(canvas)

    draw_multiline(draw, (86, 286), [">触摸：移动鼠标指针", ">单击：鼠标左键确认"], black, label_font)
    callout(draw, (380, 344), (575, 472))

    draw_multiline(draw, (88, 528), [">单击：鼠标左键单击", ">双击：鼠标左键双击"], black, label_font)
    callout(draw, (380, 564), (612, 522))

    draw_multiline(
        draw,
        (520, 150),
        [">上滑：鼠标滚轮上滚", ">下滑：鼠标滚轮下滚", ">单击：鼠标中键单击", ">双击：鼠标中键双击"],
        black,
        label_font,
    )
    callout(draw, (690, 300), (674, 330))

    draw_multiline(draw, (892, 336), [">单击：鼠标右键单击", ">双击：返回/后退", ">长按：自定义快捷键"], black, label_font)
    callout(draw, (884, 402), (790, 390))

    draw.rounded_rectangle((72, 704, 1208, 756), radius=12, outline=(230, 232, 236), width=2, fill=(248, 250, 252))
    draw.text((102, 718), "默认面向鼠标化操作；自定义按键可在设置窗口中点击“录制”后绑定。", fill=(72, 80, 88), font=footer_font)
    draw.text((76, 772), "RGR06 Mapper v0.19", fill=red, font=small_font)

    canvas.convert("RGB").save(OUT, quality=95)
    print(OUT)


if __name__ == "__main__":
    main()
