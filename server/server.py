"""Formula OCR API. Run one Uvicorn worker per model instance."""
import asyncio
import hashlib
import logging
import multiprocessing as mp
import os
import queue
import time
from collections import OrderedDict
from contextlib import asynccontextmanager
from io import BytesIO

import numpy as np
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from PIL import Image, ImageDraw, ImageFont, ImageOps, UnidentifiedImageError

log = logging.getLogger('uvicorn.error')
MODEL_NAME = os.getenv('FORMULA_MODEL_NAME', 'PP-FormulaNet_plus-M')
MODEL_DEVICE = os.getenv('FORMULA_DEVICE', 'cpu')
CPU_THREADS = max(1, int(os.getenv('FORMULA_CPU_THREADS', min(2, os.cpu_count() or 1))))
INFERENCE_TIMEOUT = float(os.getenv('FORMULA_INFERENCE_TIMEOUT', '30'))
STARTUP_TIMEOUT = float(os.getenv('FORMULA_STARTUP_TIMEOUT', '120'))
QUEUE_TIMEOUT = float(os.getenv('FORMULA_QUEUE_TIMEOUT', '10'))
CACHE_SIZE = max(0, int(os.getenv('FORMULA_CACHE_SIZE', '32')))
MAX_IMAGE_BYTES = 10 * 1024 * 1024
MAX_IMAGE_PIXELS = 20_000_000
MAX_IMAGE_SIDE = 2048


def preprocess_image(img: Image.Image, mode: str = 'photo') -> Image.Image:
    """Preserve photo tones; crop only the app's white drawing canvas."""
    img = ImageOps.exif_transpose(img)
    if img.mode in ('RGBA', 'LA') or 'transparency' in img.info:
        rgba = img.convert('RGBA')
        background = Image.new('RGBA', img.size, 'white')
        img = Image.alpha_composite(background, rgba).convert('RGB')
    else:
        img = img.convert('RGB')
    if mode == 'drawing':
        ink = img.convert('L').point(lambda value: 255 if value < 245 else 0)
        bounds = ink.getbbox()
        if bounds is None:
            raise ValueError('Нарисуйте формулу на холсте')
        img = ImageOps.expand(img.crop(bounds), border=20, fill='white')
    img.thumbnail((MAX_IMAGE_SIDE, MAX_IMAGE_SIDE), Image.Resampling.LANCZOS)
    return img


def model_input(img: Image.Image) -> np.ndarray:
    # PaddleX ReadImage interprets ndarray inputs as BGR, even for RGB models.
    return np.ascontiguousarray(np.asarray(img)[:, :, ::-1])


def clean_latex(latex: str) -> str:
    latex = ' '.join(latex.strip().split())
    if latex.startswith('$$') and latex.endswith('$$'):
        return latex[2:-2].strip()
    if latex.startswith('$') and latex.endswith('$'):
        return latex[1:-1].strip()
    return latex


def predict_formula(model, img: Image.Image) -> str:
    for result in model.predict(input=model_input(img), batch_size=1):
        latex = clean_latex(result.get('rec_formula', ''))
        if latex:
            return latex
    raise RuntimeError('FormulaNet не вернул формулу')


def inference_worker(requests, responses):
    try:
        # Import only in the spawned child: no Paddle state inherited by fork.
        from paddlex import create_model
        model = create_model(
            model_name=MODEL_NAME,
            device=MODEL_DEVICE,
            engine_config={'cpu_threads': CPU_THREADS} if MODEL_DEVICE == 'cpu' else None,
        )
        warmup = Image.new('RGB', (320, 100), 'white')
        ImageDraw.Draw(warmup).text((20, 20), 'x + 1 = 2', fill='black', font=ImageFont.load_default(size=40))
        predict_formula(model, warmup)
        responses.put((0, {'ready': True}))
    except Exception:
        log.exception('Formula model failed to initialize')
        responses.put((0, {'error': 'Formula model failed to initialize'}))
        return
    while True:
        request = requests.get()
        if request is None:
            return
        request_id, image_bytes, mode = request
        started = time.perf_counter()
        try:
            with Image.open(BytesIO(image_bytes)) as img:
                prepared = preprocess_image(img, mode)
            latex = predict_formula(model, prepared)
            responses.put((request_id, {'latex': latex}))
            # Avoid logging uploaded images or recognized user content.
            print(f'Inference {request_id}: {time.perf_counter() - started:.3f}s', flush=True)
        except ValueError as exc:
            responses.put((request_id, {'invalid': str(exc)}))
        except Exception:
            log.exception('Formula inference failed')
            responses.put((request_id, {'error': 'Recognition failed'}))


class FormulaWorker:
    def __init__(self):
        self.context = mp.get_context('spawn')
        self.process = None
        self.requests = None
        self.responses = None
        self.ready = False
        self.request_id = 0
        self.lock = asyncio.Lock()
        self.cache = OrderedDict()

    def start(self):
        self.ready = False
        self.requests = self.context.Queue()
        self.responses = self.context.Queue()
        self.process = self.context.Process(target=inference_worker, args=(self.requests, self.responses), daemon=True)
        self.process.start()

    def stop(self):
        self.ready = False
        if self.process is not None:
            if self.process.is_alive():
                self.requests.put(None)
                self.process.join(timeout=2)
            if self.process.is_alive():
                self.process.kill()
                self.process.join(timeout=2)
            self.process.close()
            self.process = None
        for channel in (self.requests, self.responses):
            if channel is not None:
                channel.cancel_join_thread()
                channel.close()
        self.requests = self.responses = None

    async def response(self, request_id, timeout):
        deadline = asyncio.get_running_loop().time() + timeout
        while True:
            remaining = deadline - asyncio.get_running_loop().time()
            if remaining <= 0:
                raise TimeoutError('Recognition timeout')
            try:
                response_id, result = await asyncio.to_thread(self.responses.get, True, min(remaining, 0.2))
            except queue.Empty:
                if self.process is None or not self.process.is_alive():
                    self.ready = False
                    raise RuntimeError('Formula worker stopped')
                continue
            if response_id == request_id:
                if 'error' in result:
                    raise RuntimeError(result['error'])
                if 'invalid' in result:
                    raise ValueError(result['invalid'])
                return result

    async def wait_ready(self):
        await self.response(0, STARTUP_TIMEOUT)
        self.ready = True

    def cached(self, key):
        result = self.cache.get(key)
        if result is not None:
            self.cache.move_to_end(key)
        return result

    async def recognize(self, image_bytes: bytes, mode: str) -> str:
        key = (mode, hashlib.sha256(image_bytes).digest())
        cached = self.cached(key)
        if cached is not None:
            return cached
        try:
            await asyncio.wait_for(self.lock.acquire(), timeout=QUEUE_TIMEOUT)
        except TimeoutError as exc:
            raise HTTPException(503, 'Сервер занят. Повторите попытку.', headers={'Retry-After': '2'}) from exc
        try:
            cached = self.cached(key)
            if cached is not None:
                return cached
            if self.process is None or not self.process.is_alive():
                await asyncio.to_thread(self.stop)
                self.start()
            if not self.ready:
                await self.wait_ready()
            self.request_id += 1
            self.requests.put((self.request_id, image_bytes, mode))
            try:
                result = await self.response(self.request_id, INFERENCE_TIMEOUT)
            except (TimeoutError, RuntimeError, asyncio.CancelledError):
                # Stop off the event loop; a later request loads a fresh worker.
                await asyncio.to_thread(self.stop)
                raise
            latex = result['latex']
            if CACHE_SIZE:
                self.cache[key] = latex
                while len(self.cache) > CACHE_SIZE:
                    self.cache.popitem(last=False)
            return latex
        finally:
            self.lock.release()


worker = FormulaWorker()


@asynccontextmanager
async def lifespan(app: FastAPI):
    worker.start()
    try:
        await worker.wait_ready()
        log.info('Formula model ready: %s, %s, cpu_threads=%s', MODEL_NAME, MODEL_DEVICE, CPU_THREADS)
        yield
    finally:
        await asyncio.to_thread(worker.stop)


app = FastAPI(lifespan=lifespan)


@app.get('/health')
async def health():
    if not worker.ready or worker.process is None or not worker.process.is_alive():
        raise HTTPException(503, 'Model is not ready')
    return {'status': 'ready', 'model': MODEL_NAME}


def validate_image(image_bytes: bytes):
    try:
        with Image.open(BytesIO(image_bytes)) as img:
            if img.width * img.height > MAX_IMAGE_PIXELS:
                raise HTTPException(413, 'Image has too many pixels')
            img.verify()
    except HTTPException:
        raise
    except (UnidentifiedImageError, OSError, ValueError, SyntaxError, Image.DecompressionBombError) as exc:
        raise HTTPException(400, 'Invalid image') from exc


@app.post('/recognize')
async def recognize(image: UploadFile = File(...), mode: str = Form('photo')):
    if mode not in {'photo', 'drawing'}:
        raise HTTPException(400, "mode must be 'photo' or 'drawing'")
    image_bytes = await image.read(MAX_IMAGE_BYTES + 1)
    if not image_bytes:
        raise HTTPException(400, 'Empty image')
    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(413, 'Image is too large')
    await asyncio.to_thread(validate_image, image_bytes)
    try:
        latex = await worker.recognize(image_bytes, mode)
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc
    except TimeoutError as exc:
        raise HTTPException(504, 'Recognition timeout') from exc
    except RuntimeError as exc:
        raise HTTPException(503, 'Recognition temporarily unavailable') from exc
    return {'latex': latex, 'mode': mode}
