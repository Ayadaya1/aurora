import asyncio
import multiprocessing as mp
import os
import queue
import tempfile
from contextlib import asynccontextmanager
from io import BytesIO

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from PIL import Image, ImageOps
from paddlex import create_model


MODEL_NAME = "PP-FormulaNet_plus-M"
MODEL_DEVICE = "cpu"
INFERENCE_TIMEOUT = 30
MAX_IMAGE_BYTES = 10 * 1024 * 1024
MAX_IMAGE_PIXELS = 20_000_000

def preprocess_image(img: Image.Image) -> Image.Image:
    img = ImageOps.exif_transpose(img)
    img = img.convert("RGB")

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


def inference_worker(
        request_queue: mp.Queue,
        response_queue: mp.Queue,
):

    print(f"Loading {MODEL_NAME} in worker...", flush=True)

    from paddlex import create_model

    model = create_model(
        model_name=MODEL_NAME,
        device=MODEL_DEVICE,
    )

    print("FormulaNet loaded in worker", flush=True)

    while True:
        request = request_queue.get()

        if request is None:
            print("Worker stopping...", flush=True)
            break

        request_id, image_bytes = request

        temp_path = None

        try:
            img = Image.open(
                BytesIO(image_bytes)
            )

            img.load()

            img = preprocess_image(img)

            with tempfile.NamedTemporaryFile(
                    suffix=".png",
                    delete=False,
            ) as tmp:
                temp_path = tmp.name

            img.save(
                temp_path,
                format="PNG",
            )

            print(
                f"Starting inference {request_id}",
                flush=True,
            )

            results = model.predict(
                input=temp_path,
                batch_size=1,
            )

            latex = None

            for result in results:
                print(
                    f"FormulaNet result {request_id}:",
                    result,
                    flush=True,
                )

                latex = result.get(
                    "rec_formula",
                    "",
                )

                if latex:
                    latex = clean_latex(latex)

                if latex:
                    break

            if not latex:
                raise ValueError(
                    "FormulaNet не вернул формулу"
                )

            response_queue.put(
                (
                    request_id,
                    {
                        "success": True,
                        "latex": latex,
                    },
                )
            )

        except Exception as exc:
            print(
                f"Worker error {request_id}:",
                repr(exc),
                flush=True,
            )

            response_queue.put(
                (
                    request_id,
                    {
                        "success": False,
                        "error": repr(exc),
                    },
                )
            )

        finally:
            if temp_path is not None:
                try:
                    os.unlink(temp_path)
                except OSError:
                    pass


class FormulaWorker:
    def __init__(self):
        self.request_queue = None
        self.response_queue = None
        self.process = None

        self.request_id = 0

        # Один запрос за раз.
        self.lock = asyncio.Lock()

    def start(self):
        print("Starting FormulaNet worker...")

        self.request_queue = mp.Queue()
        self.response_queue = mp.Queue()

        self.process = mp.Process(
            target=inference_worker,
            args=(
                self.request_queue,
                self.response_queue,
            ),
            daemon=True,
        )

        self.process.start()

        print(
            f"FormulaNet worker started: PID={self.process.pid}"
        )

    def stop(self):
        if self.process is None:
            return

        if self.process.is_alive():
            try:
                self.request_queue.put(None)
            except Exception:
                pass

            self.process.join(timeout=5)

        if self.process.is_alive():
            print(
                f"Worker did not stop gracefully. "
                f"Killing PID={self.process.pid}"
            )

            self.process.kill()
            self.process.join()

        self.process = None

    def restart(self):
        print("Restarting FormulaNet worker...")

        self.stop()

        self.start()

    async def recognize(
            self,
            image_bytes: bytes,
    ) -> str:

        async with self.lock:
            if (
                    self.process is None
                    or not self.process.is_alive()
            ):
                self.restart()

            self.request_id += 1
            request_id = self.request_id

            self.request_queue.put(
                (
                    request_id,
                    image_bytes,
                )
            )

            loop = asyncio.get_running_loop()

            deadline = (
                    loop.time()
                    + INFERENCE_TIMEOUT
            )

            while True:
                remaining = (
                        deadline
                        - loop.time()
                )

                if remaining <= 0:
                    print(
                        f"Recognition timeout "
                        f"for request {request_id}"
                    )

                    self.restart()

                    raise TimeoutError(
                        f"Recognition exceeded "
                        f"{INFERENCE_TIMEOUT} seconds"
                    )

                try:
                    response_id, response = (
                        await asyncio.to_thread(
                            self.response_queue.get,
                            True,
                            min(remaining, 0.5),
                        )
                    )

                except queue.Empty:
                    if (
                            self.process is None
                            or not self.process.is_alive()
                    ):
                        self.restart()

                        raise RuntimeError(
                            "FormulaNet worker crashed"
                        )

                    continue

                if response_id != request_id:
                    continue

                if not response["success"]:
                    raise RuntimeError(
                        response["error"]
                    )

                return response["latex"]



worker = FormulaWorker()


@asynccontextmanager
async def lifespan(app: FastAPI):
    worker.start()

    yield

    print("Shutting down FormulaNet worker...")

    worker.stop()


app = FastAPI(
    lifespan=lifespan,
)


# ---------------------------------------------------------
# API
# ---------------------------------------------------------

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

    # Проверяем, что это действительно изображение.
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
        latex = await worker.recognize(
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


