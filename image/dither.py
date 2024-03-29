#! /usr/bin/env python

"""Scale, rotate, and dither the mood image, generating a sequence of images covering 90° of rotation.

The source image is from wikipedia: https://en.wikipedia.org/wiki/Moon#/media/File:FullMoon2010.jpg,
scaled to 512x512 using Preview.app.
"""

import json
import math
import numpy as np
import sys

from PIL import Image
from PIL.Image import Resampling, Palette

RAW_SIZE = 512
CROP_PIXELS = 2  # To reduce some apparent artifacts seen around the edges of the disk


def main():
    dir = sys.argv[1]

    src = Image.open(f"FullMoon2010-{RAW_SIZE}.png")
    src = src.crop((CROP_PIXELS, CROP_PIXELS, RAW_SIZE-CROP_PIXELS, RAW_SIZE-CROP_PIXELS))

    # # Test how much detail is preserved by the dithering:
    # munge(src, 0, 500).show()

    radius = 35
    steps = 50  # Note: radius*π/2 or about radius*1.5 would be one-pixel steps around the perimeter
    for i in range(steps):
        name = f"moon{radius}-{i:02d}.png"
        img = munge(src, 90*i/steps, radius)
        img.save(f"{dir}/{name}")
        print(f"""  <bitmap id="Moon{radius}_{i:02d}" filename="{name}" />""")

    icon = munge(src, 0, 20)
    icon.save(f"{dir}/launcher_icon40.png")


def munge(img, angle, radius):
    """Rotate, resize, and dither (in that order)."""

    img = img.rotate(-angle, resample=Resampling.BICUBIC, fillcolor=(0, 0, 0))

    img = img.resize((2*radius, 2*radius), resample=Resampling.BICUBIC)

    img = dither_mask(img)

    return img


def dither_mask(img):
    """Convert image to greyscale, then dither to four pixel values, using mode "RGBA",
    and finally set all pixels outside of a central circle to transparent.

    The brightest pixel in the source is assigned the "white output value. All other values
    are scaled linearly.

    The Floyd-Steinberg diffusion weights are used.
    """

    src = np.asarray(img.convert(mode="L"))
    size = src.shape[0]

    # The source image isn't very bright, so just treat its maximum individual pixel value as
    # white and scale verything else linearly:
    max_raw = max(src[r, c] for r in range(size) for c in range(size))

    # Scale values to the range 0.0 to 1.0, and add some space below and right for error diffusion:
    vals = np.zeros((size+2, size+2), np.float32)
    vals[0:size, 0:size] = src/max_raw

    # Quantize to the 4 available gray levels, using `vals` to accumulate errors as we go:
    dst = np.zeros((size, size, 4), dtype=np.uint8)
    for y in range(size):
        for x in range(size):
            # Note: this value has already been adjusted to account for error diffused from above and left
            val = vals[y, x]

            # Divide the range of values into 4 equal sub-ranges, and assign a color to each.
            # Note: both the thresholds and the associated `qval` for each could be used to
            # manipulate the brightness/contrast of the result.
            if val > 3/4:
                qval = 1
                pval = 0xFF
            elif val > 1/2:
                qval = 2/3
                pval = 0xAA
            elif val > 1/4:
                qval = 1/3
                pval = 0x55
            else:
                qval = 0
                pval = 0x00

            err = val - qval

            # Floyd-Steinberg distribution:
            vals[y  , x+1] += err * 7/16
            vals[y+1, x-1] += err * 3/16
            vals[y+1, x  ] += err * 5/16
            vals[y+1, x+1] += err * 1/16

            # Atkinson:
            # vals[y  , x+1] += err * 1/8
            # vals[y  , x+2] += err * 1/8
            # vals[y+1, x-1] += err * 1/8
            # vals[y+1, x  ] += err * 1/8
            # vals[y+1, x+1] += err * 1/8
            # vals[y+2, x  ] += err * 1/8

            r = math.sqrt((x + 0.5 - size/2)**2 + (y + 0.5 - size/2)**2)
            if r < size/2:
                dst[y, x] = (pval, pval, pval, 0xFF)
            else:
                dst[y, x] = (0, 0, 0, 0x00)

    return Image.fromarray(dst, mode="RGBA")


if __name__ == "__main__":
    main()
