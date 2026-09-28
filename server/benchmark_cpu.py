import json, sys, time
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from paddlex import create_model

folder = Path('/tmp/aurora-formula-benchmark')
folder.mkdir(exist_ok=True)
font = ImageFont.load_default(size=64)
image = Image.new('RGB', (640, 220), 'white')
ImageDraw.Draw(image).text((75, 65), 'x + 1 = 2', font=font, fill='black')
image.save(folder/'linear.png')
image = Image.new('RGB', (640, 300), 'white')
draw = ImageDraw.Draw(image)
draw.text((80, 110), 'y =', font=font, fill='black')
draw.text((260, 55), 'x + 1', font=font, fill='black')
draw.line((250, 145, 465, 145), fill='black', width=3)
draw.text((260, 165), 'x - 1', font=font, fill='black')
image.save(folder/'fraction.png')
image = Image.new('RGB', (900, 650), 'white')
draw = ImageDraw.Draw(image)
draw.text((310, 280), 'x + 1 = 2', font=ImageFont.load_default(size=28), fill='black')
image.save(folder/'sparse.png')
image = Image.new('RGBA', (640, 220), (0, 0, 0, 0))
ImageDraw.Draw(image).text((75, 65), 'x + 1 = 2', font=font, fill='black')
image.save(folder/'transparent.png')
threads = int(sys.argv[1])
model = create_model(model_name='PP-FormulaNet_plus-M', device='cpu', engine_config={'cpu_threads': threads})
for run in range(3):
    for name in ['linear', 'fraction', 'sparse']:
        start = time.perf_counter()
        latex = next(iter(model.predict(input=str(folder/f'{name}.png'), batch_size=1)))['rec_formula']
        print(json.dumps({'threads': threads, 'run': run, 'image': name, 'seconds': round(time.perf_counter()-start, 4), 'latex': latex}), flush=True)
