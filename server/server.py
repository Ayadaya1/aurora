from io import BytesIO

from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from PIL import Image, ImageOps, ImageFilter
from pix2tex.cli import LatexOCR


app = FastAPI()

model = LatexOCR()


def crop_content(img: Image.Image, margin: int = 24) -> Image.Image:
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


def preprocess_drawing(img: Image.Image) -> Image.Image:
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


def preprocess_photo(img: Image.Image) -> Image.Image:
    img = ImageOps.exif_transpose(img)
    img = img.convert("L")

    img = ImageOps.autocontrast(img)

    img = crop_content(img, margin=40)

    img = img.filter(
        ImageFilter.UnsharpMask(
            radius=1.5,
            percent=130,
            threshold=4,
        )
    )

    return img


def preprocess(img: Image.Image, mode: str) -> Image.Image:
    if mode == "drawing":
        return preprocess_drawing(img)

    return preprocess_photo(img)


def clean_latex(latex: str) -> str:
    latex = latex.strip()

    latex = latex.replace("\n", " ")
    latex = " ".join(latex.split())

    if latex.startswith("$$") and latex.endswith("$$"):
        latex = latex[2:-2].strip()

    if latex.startswith("$") and latex.endswith("$"):
        latex = latex[1:-1].strip()

    return latex


def latex_score(latex: str) -> int:
    score = 0

    if latex:
        score += 1

    if latex.count("{") == latex.count("}"):
        score += 2

    if latex.count("[") == latex.count("]"):
        score += 1

    if latex.count("(") == latex.count(")"):
        score += 1

    if "\\frac" in latex:
        score += 1

    if "\\" in latex:
        score += 1

    return score


def recognize_with_candidates(img: Image.Image) -> str:
    original_temperature = model.args.temperature

    candidates = []

    try:
        for temperature in (0.15, 0.25, 0.35):
            model.args.temperature = temperature

            latex = model(img, resize=True)
            latex = clean_latex(latex)

            if latex:
                candidates.append(latex)
    finally:
        model.args.temperature = original_temperature

    if not candidates:
        raise ValueError("Модель не вернула формулу")

    return max(candidates, key=latex_score)


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
        img = preprocess(img, mode)
        latex = recognize_with_candidates(img)
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Recognition failed: {exc}",
        )

    return {
        "latex": latex,
        "mode": mode,
    }