import os
import tempfile
from io import BytesIO

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from PIL import Image, ImageFilter, ImageOps
from paddlex import create_model
from pix2tex.cli import LatexOCR


app = FastAPI()


# Печатные / сфотографированные формулы.
pix2tex_model = LatexOCR()


# Рукописные формулы.
formula_model = create_model(
    model_name="PP-FormulaNet_plus-M",
    device="cpu",
)


def crop_content(img: Image.Image, margin: int = 24) -> Image.Image:
    """Обрезает пустые поля вокруг содержимого."""
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
    Preprocessing для фотографий.

    Оставляем максимально близким к тому варианту,
    который у тебя уже хорошо работал.
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
    Сейчас намеренно минимальный preprocessing для drawing.

    Мы сначала проверяем чистый baseline FormulaNet,
    потому что именно такой PNG уже успешно распознавался
    в отдельном тесте.
    """
    return img


def clean_latex(latex: str) -> str:
    """Минимальная очистка результата модели."""
    latex = latex.strip()

    latex = latex.replace("\n", " ")
    latex = " ".join(latex.split())

    if latex.startswith("$$") and latex.endswith("$$"):
        latex = latex[2:-2].strip()

    if latex.startswith("$") and latex.endswith("$"):
        latex = latex[1:-1].strip()

    return latex


def recognize_photo(img: Image.Image) -> str:
    """Распознавание фотографии через pix2tex."""
    img = preprocess_photo(img)

    latex = pix2tex_model(img)

    return clean_latex(latex)


def recognize_drawing(img: Image.Image) -> str:
    """
    Распознавание рисунка через PP-FormulaNet_plus-M.
    """
    temp_path = None

    try:
        with tempfile.NamedTemporaryFile(
                suffix=".png",
                delete=False,
        ) as tmp:
            temp_path = tmp.name

        img.save(temp_path, format="PNG")

        results = formula_model.predict(
            input=temp_path,
            batch_size=1,
        )

        for result in results:
            print("FormulaNet result:", result)

            latex = result.get("rec_formula", "")

            if latex:
                return clean_latex(latex)

        raise ValueError("FormulaNet не вернул формулу")

    finally:
        if temp_path is not None:
            try:
                os.unlink(temp_path)
            except OSError:
                pass


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
        print(f"Recognition error ({mode}):", repr(exc))

        raise HTTPException(
            status_code=500,
            detail=f"Recognition failed: {exc}",
        )

    return {
        "latex": latex,
        "mode": mode,
    }