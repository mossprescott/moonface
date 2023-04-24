#! /usr/bin/env python

"""Convert a PNG image to raw values as a nested JSON array.

The source image is from wikipedia: https://en.wikipedia.org/wiki/Moon#/media/File:FullMoon2010.jpg,
scaled to 128x128 using Preview.app.
"""

import json
import math
from PIL import Image

SIZE = 128

# Pack a series of pixels into each 32-bit integer, ignoring the sign bit (and wasting one):
BITS_PER_PIXEL = 6
PIXELS_PER_WORD = 5

NO_VALUE = 0
MIN_VALUE = 1
MAX_VALUE = (2**BITS_PER_PIXEL)-1

def main():
    im = Image.open(f"FullMoon2010-{SIZE}.png")
    # print(dir(im))
    # print(im.width, im.height)
    # print(im.getpixel((SIZE/2, SIZE/2)))
    # im.show()

    # convert to greyscale, with a single byte value at each pixel
    gim = im.convert("L")
    # print(gim.getpixel((SIZE/2, SIZE/2)))
    # gim.show()

    # print(dict(enumerate(gim.histogram())))

    max_raw = max(gim.getpixel((c, r)) for r in range(SIZE) for c in range(SIZE))
    # print(f"max_raw: {max_raw}")

    # explicitly mask off anything outside the expected radius, with a little adjustment:
    radius = SIZE/2 + 0.5

    def lookup(r, c):
        x = r - SIZE/2
        y = c - SIZE/2
        if x*x + y*y > radius*radius:
            return NO_VALUE
        else:
            raw = gim.getpixel((c, r))

            # Simple ramp for testing:
            # raw = max_raw*(r+c)/(SIZE*2)

            # Note: here would be the place to apply any gamma or other massaging.
            # for now, just pin the value to fit in the allocated bits, and never 0.
            return min(MAX_VALUE, max(MIN_VALUE, round(MAX_VALUE*raw/(max_raw-1))))

    rows = [
        [lookup(row, col) for col in range(SIZE)]
        for row in range(SIZE)
    ]

    # for row in rows: print(row)
    # max_scaled = max(rows[r][c] for r in range(SIZE) for c in range(SIZE))
    # print(f"max_scaled: {max_scaled}")

    packed = [
        [pack(row[c:c+PIXELS_PER_WORD]) for c in range(0, SIZE, PIXELS_PER_WORD)]
        for row in rows
    ]

    lines = ",\n".join(",".join(str(x) for x in row) for row in packed)

    print("[")
    print(lines)
    print("]")


def pack(values):
    """Pack any number of values into a single integer, using the same number of
    bits for each pixel, and placing the first value in the least-significant bits.
    """

    if len(values) > PIXELS_PER_WORD:
        raise Exception(f"Too many values: {values}")

    acc = 0
    for x in reversed(values):
        if not (0 <= x <= MAX_VALUE):
            raise Exception(f"Unexpected value: {x} (found in {values})")
        acc = (acc << BITS_PER_PIXEL) | x
    return acc

# long_max = 2**63-1
# print(long_max)
# print(pack([1,2,3,4,5,6,7,8,9]))
# int_max = 2**31-1
# print(hex(int_max))
# print(hex(pack([21,22,23,24,25])))


if __name__ == "__main__":
    main()
