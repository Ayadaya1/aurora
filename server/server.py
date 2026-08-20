from io import BytesIO

from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from PIL import Image, ImageOps, ImageFilter
from pix2tex.cli import LatexOCR
from paddlex import create_model


app = FastAPI()

# Печатные / сфотографированные формулы
pix2tex_model = LatexOCR()

# Рукописные формулы
formula_model = create_model(
    model_name="PP-FormulaNet_plus-M",
    device="cpu",
)


def crop_content(img: Image.Image, margin: int = 24) -> Image.Image:
    """
    Обрезает пустые поля вокруг содержимого.
    Хорошо подходит для рисунка с Canvas.
    """
    gray = img.convert("L")
    inverted = ImageOps.invert(gray)

    bbox = inverted.getbbox()

    if bbox is None:
        return gray

    left, top, right, bottom = bbox

    left = max(0, left - margin)
    top = max(0, top - margin)
    right = min(gray.width, right + margin)
    bottom = min(gray.height, bottom + margin)

    return gray.crop((left, top, right, bottom))


def preprocess_photo(img: Image.Image) -> Image.Image:
    """
    Текущий удачный preprocessing для фотографий.
    Не делаем aggressive crop/binarization, чтобы не портить pix2tex.
    """
    img = ImageOps.exif_transpose(img)
    img = img.convert("L")

    scale = 2
    img = img.resize(
        (img.width * scale, img.height * scale),
        Image.Resampling.LANCZOS,
    )

    img = ImageOps.autocontrast(img)

    img = img.filter(
        ImageFilter.UnsharpMask(
            radius=1.5,
            percent=130,
            threshold=4,
        )
    )

    return img


def preprocess_drawing(img: Image.Image) -> Image.Image:
    """
    Preprocessing для чистого PNG с Canvas.
    """
    img = ImageOps.exif_transpose(img)
    img = img.convert("L")

    img = ImageOps.autocontrast(img)

    img = crop_content(img, margin=32)

    img = img.filter(
        ImageFilter.UnsharpMask(
            radius=1.5,
            percent=140,
            threshold=3,
        )
    )

    return img


def clean_latex(latex: str) -> str:
    latex = latex.strip()

    latex = latex.replace("\n", " ")
    latex = " ".join(latex.split())

    if latex.startswith("$$") and latex.endswith("$$"):
        latex = latex[2:-2].strip()

    if latex.startswith("$") and latex.endswith("$"):
        latex = latex[1:-1].strip()

    return latex


def recognize_photo(img: Image.Image) -> str:
    img = preprocess_photo(img)

    latex = pix2tex_model(img)

    return clean_latex(latex)


def recognize_drawing(img: Image.Image) -> str:
    img = preprocess_drawing(img)

    # PaddleX возвращает генератор результатов.
    results = formula_model.predict(
        input=img,
        batch_size=1,
    )

    for result in results:
        # В актуальном PaddleX результат содержит:
        # result["res"]["rec_formula"]
        data = result["res"]

        latex = data.get("rec_formula", "")

        if latex:
            return clean_latex(latex)

    raise ValueError("FormulaNet не вернул формулу")


@app.post("/recognize")
async def recognize(
        image: UploadFile = File(...),
        mode: str = Form("photo"),
):
    if mode not in {"photo", "drawing"}:
        raise HTTPException(
            status_code=400,
            detail="mode must be 'photo' or 'drawing'",
        )

    image_bytes = await image.read()

    if not image_bytes:
        raise HTTPException(
            status_code=400,
            detail="Empty image",
        )

    try:
        img = Image.open(BytesIO(image_bytes))
        img.load()
    except Exception as exc:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid image: {exc}",
        )

    try:
        if mode == "drawing":
            latex = recognize_drawing(img)
        else:
            latex = recognize_photo(img)

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Recognition failed: {exc}",
        )

    return {
        "latex": latex,
        "mode": mode,
    }