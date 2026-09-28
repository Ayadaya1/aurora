import unittest
from io import BytesIO
from unittest.mock import AsyncMock, patch

import numpy as np
from fastapi.testclient import TestClient
from PIL import Image, ImageDraw

import server


def png(img):
    buffer = BytesIO()
    img.save(buffer, format='PNG')
    return buffer.getvalue()


class PreprocessingTests(unittest.TestCase):
    def test_transparency_becomes_white_without_losing_black_ink(self):
        img = Image.new('RGBA', (50, 30), (0, 0, 0, 0))
        img.putpixel((10, 10), (0, 0, 0, 255))
        result = server.preprocess_image(img)
        self.assertEqual(result.getpixel((0, 0)), (255, 255, 255))
        self.assertEqual(result.getpixel((10, 10)), (0, 0, 0))

    def test_drawing_crop_keeps_superscripts_and_padding(self):
        img = Image.new('RGB', (900, 650), 'white')
        draw = ImageDraw.Draw(img)
        draw.line((400, 300, 450, 350), fill='black', width=3)
        draw.point((460, 280), fill='black')
        result = server.preprocess_image(img, 'drawing')
        self.assertLess(result.width, 150)
        self.assertEqual(result.getpixel((result.width-21, 20)), (0, 0, 0))
        self.assertEqual(server.preprocess_image(img, 'photo').size, img.size)

    def test_empty_drawing_has_actionable_error(self):
        with self.assertRaisesRegex(ValueError, 'Нарисуйте'):
            server.preprocess_image(Image.new('RGB', (50, 50), 'white'), 'drawing')

    def test_numpy_input_uses_paddlex_bgr_order(self):
        data = server.model_input(Image.new('RGB', (1, 1), (10, 20, 30)))
        np.testing.assert_array_equal(data[0, 0], [30, 20, 10])
        self.assertTrue(data.flags.c_contiguous)

    def test_exif_orientation_is_applied(self):
        img = Image.new('RGB', (60, 30), 'white')
        img.getexif()[274] = 6
        self.assertEqual(server.preprocess_image(img).size, (30, 60))

    def test_large_photo_is_bounded_and_aspect_ratio_kept(self):
        result = server.preprocess_image(Image.new('RGB', (4096, 2048), 'white'))
        self.assertEqual(result.size, (2048, 1024))


class ApiTests(unittest.TestCase):
    def setUp(self):
        # No lifespan here: unit tests must not load/download the neural model.
        self.client = TestClient(server.app)
        self.image = png(Image.new('RGB', (30, 30), 'white'))

    def post(self, data=None, content=None):
        return self.client.post('/recognize', data=data or {}, files={'image': ('image.png', self.image if content is None else content, 'image/png')})

    def test_passes_drawing_mode_and_preserves_api(self):
        with patch.object(server.worker, 'recognize', AsyncMock(return_value='x+1=2')) as recognize:
            response = self.post({'mode': 'drawing'})
            self.assertEqual(response.json(), {'latex': 'x+1=2', 'mode': 'drawing'})
            recognize.assert_awaited_once_with(self.image, 'drawing')

    def test_invalid_uploads_are_rejected_before_inference(self):
        with patch.object(server.worker, 'recognize', AsyncMock()) as recognize:
            self.assertEqual(self.post({'mode': 'unknown'}).status_code, 400)
            self.assertEqual(self.post(content=b'').status_code, 400)
            self.assertEqual(self.post(content=b'not an image').status_code, 400)
            with patch.object(server, 'MAX_IMAGE_BYTES', 8):
                self.assertEqual(self.post(content=b'123456789').status_code, 413)
            with patch.object(server, 'MAX_IMAGE_PIXELS', 10):
                self.assertEqual(self.post().status_code, 413)
            recognize.assert_not_awaited()

    def test_model_timeout_is_504(self):
        with patch.object(server.worker, 'recognize', AsyncMock(side_effect=TimeoutError)):
            self.assertEqual(self.post().status_code, 504)

    def test_unready_health_is_503(self):
        self.assertEqual(self.client.get('/health').status_code, 503)


class CacheTests(unittest.IsolatedAsyncioTestCase):
    async def test_repeated_input_is_cached_but_mode_is_part_of_key(self):
        from unittest.mock import Mock
        worker = server.FormulaWorker()
        worker.process = Mock()
        worker.process.is_alive.return_value = True
        worker.ready = True
        worker.requests = Mock()
        worker.response = AsyncMock(return_value={'latex': 'x'})
        self.assertEqual(await worker.recognize(b'image', 'photo'), 'x')
        self.assertEqual(await worker.recognize(b'image', 'photo'), 'x')
        self.assertEqual(worker.response.await_count, 1)
        await worker.recognize(b'image', 'drawing')
        self.assertEqual(worker.response.await_count, 2)
        with patch.object(server, 'CACHE_SIZE', 1):
            await worker.recognize(b'another', 'photo')
            self.assertEqual(len(worker.cache), 1)

    async def test_busy_worker_does_not_queue_indefinitely(self):
        worker = server.FormulaWorker()
        await worker.lock.acquire()
        with patch.object(server, 'QUEUE_TIMEOUT', 0.01):
            with self.assertRaises(server.HTTPException) as caught:
                await worker.recognize(b'image', 'photo')
        self.assertEqual(caught.exception.status_code, 503)
        worker.lock.release()


if __name__ == '__main__':
    unittest.main()
