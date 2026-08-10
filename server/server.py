from io import BytesIO

from fastapi import FastAPI, File, UploadFile
from PIL import Image
from pix2tex.cli import LatexOCR
from PIL import Image, ImageOps, ImageFilter


def preprocess(img: Image.Image) -> Image.Image:
    img = img.convert("L")

    scale = 2
    img = img.resize(
        (img.width * scale, img.height * scale),
        Image.Resampling.LANCZOS,
    )

    img = ImageOps.autocontrast(img)

    img = img.filter(ImageFilter.SHARPEN)

    return img

app = FastAPI()

model = LatexOCR()



@app.post("/recognize")
async def recognize(image: UploadFile = File(...)):
    image_bytes = await image.read()
    img = Image.open(BytesIO(image_bytes))
    img = preprocess(img)

    latex = model(img)

    return {
        "latex": latex
    }