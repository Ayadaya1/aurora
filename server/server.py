import asyncio
import os
import tempfile
from contextlib import asynccontextmanager
from concurrent.futures import ProcessPoolExecutor
from io import BytesIO

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from PIL import Image, ImageOps
from paddlex import create_model


MODEL_NAME = "PP-FormulaNet_plus-M"
MODEL_DEVICE = "cpu"

# Максимальное время распознавания одной картинки.
INFERENCE_TIMEOUT = 30

# Не позволяем нескольким тяжёлым CPU inference идти одновременно.
INFERENCE_WORKERS = 1

# Защита от огромных изображений.
MAX_IMAGE_BYTES = 10 * 1024 * 1024
MAX_IMAGE_PIXELS = 20_000_000


formula_model = None
executor = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global formula_model
    global executor

    print(f"Loading {MODEL_NAME}...")

    formula_model = create_model(
        model_name=MODEL_NAME,
        device=MODEL_DEVICE,
    )

    executor = ProcessPoolExecutor(
        max_workers=INFERENCE_WORKERS,
    )

    print("FormulaNet loaded")

    yield

    print("Shutting down...")

    executor.shutdown(
        wait=True,
        cancel_futures=True,
    )


app = FastAPI(lifespan=lifespan)


def preprocess_image(img: Image.Image) -> Image.Image:
    img = ImageOps.exif_transpose(img)
    img = img.convert("RGB")

    # Не даём огромным изображениям случайно убить CPU/RAM.
    if img.width * img.height > MAX_IMAGE_PIXELS:
        scale = (
                        MAX_IMAGE_PIXELS
                        / (img.width * img.height)
                ) ** 0.5

        new_size = (
            max(1, int(img.width * scale)),
            max(1, int(img.height * scale)),
        )

        img = img.resize(
            new_size,
            Image.Resampling.LANCZOS,
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


def recognize_with_formulanet(image_bytes: bytes) -> str:
    """
    Выполняется в отдельном process.

    Если этот process зависнет, основной FastAPI process
    сможет его уничтожить.
    """

    from io import BytesIO
    from PIL import Image
    from paddlex import create_model

    model = create_model(
        model_name=MODEL_NAME,
        device=MODEL_DEVICE,
    )

    img = Image.open(
        BytesIO(image_bytes)
    )

    img.load()

    img = preprocess_image(img)

    temp_path = None

    try:
        with tempfile.NamedTemporaryFile(
                suffix=".png",
                delete=False,
        ) as tmp:
            temp_path = tmp.name

        img.save(
            temp_path,
            format="PNG",
        )

        results = model.predict(
            input=temp_path,
            batch_size=1,
        )

        for result in results:
            print("FormulaNet result:", result)

            latex = result.get(
                "rec_formula",
                "",
            )

            if latex:
                latex = clean_latex(latex)

                if latex:
                    return latex

        raise ValueError(
            "FormulaNet не вернул формулу"
        )

    finally:
        if temp_path is not None:
            try:
                os.unlink(temp_path)
            except OSError:
                pass


async def recognize_with_timeout(
        image_bytes: bytes,
) -> str:
    loop = asyncio.get_running_loop()

    future = loop.run_in_executor(
        executor,
        recognize_with_formulanet,
        image_bytes,
    )

    try:
        return await asyncio.wait_for(
            future,
            timeout=INFERENCE_TIMEOUT,
        )

    except asyncio.TimeoutError:
        raise TimeoutError(
            f"Recognition exceeded "
            f"{INFERENCE_TIMEOUT} seconds"
        )


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

    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(
            status_code=413,
            detail="Image is too large",
        )

    try:
        img = Image.open(
            BytesIO(image_bytes)
        )

        img.verify()

    except Exception as exc:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid image: {exc}",
        )

    try:
        latex = await recognize_with_timeout(
            image_bytes
        )

    except TimeoutError as exc:
        print(
            "Recognition timeout:",
            repr(exc),
        )

        raise HTTPException(
            status_code=504,
            detail="Recognition timeout",
        )

    except Exception as exc:
        print(
            "Recognition error:",
            repr(exc),
        )

        raise HTTPException(
            status_code=500,
            detail="Recognition failed",
        )

    return {
        "latex": latex,
        "mode": mode,
    }