#! /usr/bin/env python

"""Generate a bitmap font for drawing multiple 2-bit grayscale pixels at a time.
"""

import json
import math
import sys
import numpy as np
from PIL import Image


PIXELS_PER_CHAR = 3
NUM_CHARS = 5**PIXELS_PER_CHAR

# char 0:
# 0 0 0 0 0 => all

def main():
    dir = sys.argv[1]

    pixels = np.zeros((NUM_CHARS, PIXELS_PER_CHAR), dtype=np.int32)

    def set(x, y, val):
        if val != 0:
            pixels[y, x] = 0xFF000000 | (0x555555*(val-1))

    for row in range(NUM_CHARS):
        # set(0, row, (row//25)%5)
        # set(1, row, (row//5)%5)
        # set(2, row, row%5)
        for col in range(PIXELS_PER_CHAR):
            val = (row//(5 ** (PIXELS_PER_CHAR-col-1))) % 5
            set(col, row, val)

    im = Image.fromarray(pixels, mode="RGBA")
    # im.show()
    im.save(f"{dir}/pixels.png")

    with open(f"{dir}/pixels.fnt", "w") as f:
        f.write(f"""info face="Pixels" size=-10 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=1,1 outline=0
common lineHeight=10 base=10 scaleW=256 scaleH=256 pages=1 packed=0 alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0
page id=0 file="pixels.png"
""")
        f.write(f"chars count={NUM_CHARS}\n")
        for i in range(NUM_CHARS):
            f.write(f"char id={i} x=0 y={i} width={PIXELS_PER_CHAR} height=1 xoffset=0 yoffset=0 xadvance={PIXELS_PER_CHAR} page=0 chnl=15\n")



if __name__ == "__main__":
    main()
