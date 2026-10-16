import sys
from PIL import Image, ImageDraw
mid, x0, y0, x1, y1 = map(int, sys.argv[1:6]); esc = float(sys.argv[6]) if len(sys.argv) > 6 else 1.5
im = Image.open("r%d.png" % mid).convert("RGB").crop((x0*32, y0*32, x1*32, y1*32))
dr = ImageDraw.Draw(im)
for x in range(x0, x1):
    for y in range(y0, y1):
        dr.rectangle([(x-x0)*32, (y-y0)*32, (x-x0)*32+31, (y-y0)*32+31], outline=(90, 90, 90))
        if (x + y) % 2 == 0: dr.text(((x-x0)*32+2, (y-y0)*32+20), "%d,%d" % (x, y), fill=(255, 255, 255))
im = im.resize((int(im.width * esc), int(im.height * esc)), Image.NEAREST)
im.save("c%d_%d_%d.png" % (mid, x0, y0)); print("c%d_%d_%d.png" % (mid, x0, y0))
