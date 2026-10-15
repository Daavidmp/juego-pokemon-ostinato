from PIL import Image, ImageDraw
import sys
def ver(img_path, grid, out):
    im = Image.open(img_path).convert('RGBA')
    capa = Image.new('RGBA', im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(capa)
    for y, fila in enumerate(grid):
        for x, c in enumerate(fila):
            col = (255, 0, 0, 80) if c == '#' else (0, 255, 0, 40) if c == '.' else (255, 255, 0, 90)
            d.rectangle([x*32, y*32, x*32+31, y*32+31], fill=col, outline=(0, 0, 0, 70))
    Image.alpha_composite(im, capa).save(out)
