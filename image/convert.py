#! /usr/bin/env python

"""Convert a PNG image to raw values as a nested JSON array.
"""

import json
import math
from PIL import Image


def main():
    im = Image.open("FullMoon2010-128.png")
    # print(dir(im))
    # print(im.width, im.height)
    # print(im.getpixel((128, 128)))
    # im.show()

    # convert to greyscale, with a single byte value at each pixel
    gim = im.convert("L")
    # print(gim.getpixel((128, 128)))
    # gim.show()

    rows = [
        [gim.getpixel((row, col)) for col in range(128)]
        for row in range(128)
    ]

    # print(gim.histogram())

    # overall_max = max(max(r) for r in rows)
    # print(f"max value: {overall_max}")  # 204, but very few values over 200

    # scale to the range 0-99 so everything fits in one or two digits:
    # TODO: possibly apply some gamma here
    scaled_rows = [
        [int(x/204*99) for x in row]
        for row in rows
    ]

    # overall_max = max(max(r) for r in scaled_rows)
    # print(f"max value: {overall_max}")  # 99, just double-checking the rounding


    print("[")
    MASK_RADIUS = 64.5  # Note: this seems to cut off some pixels with data in them, but that's better than including some halo of black
    for i in range(128):
        y = i - 63.25
        approx_x = min(64, math.ceil(MASK_RADIUS*math.sin(math.acos(y/MASK_RADIUS))))  # or use pyth. th.
        row = scaled_rows[i]
        # print(f"{i}: est.: {2*approx_x}; actual: {len([v for v in row if v > 1])}")
        middle = row[64-approx_x:64+approx_x]
        print(json.dumps(middle).replace(" ", "") + ("," if i < 127 else ""))
    print("]")


if __name__ == "__main__":
    main()
