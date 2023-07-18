import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Test;
using Toybox.StringUtil;

const SIZE as Number = 128;
const BITS_PER_PIXEL as Number = 6;
const PIXELS_PER_WORD as Number = 5;

const WORDS_PER_ROW as Number = (SIZE + PIXELS_PER_WORD-1)/PIXELS_PER_WORD;
const PIXEL_MASK as Number = (1 << BITS_PER_PIXEL) - 1;
const MAX_VALUE as Float = (1 << BITS_PER_PIXEL) - 1.0;

const PIXELS_PER_CHAR = 10;
const NUM_PIXEL_CHARS = 1 << PIXELS_PER_CHAR;

// An alternative to time-based throttling. This is simpler, more consistent, and less
// affected by variation in simulation speed. On the other hand, it doesn't addapt to
// the number of pixels being renderes depending on the moon's phase.
const MAX_ROWS_PER_UPDATE = 5;

// Access and draw the pixels of an image of the moon's face. The pixels are stored in a
// JSON-formatted resource, because we want to do our own scaling, dithering, and rotation,
// and the Toybox API seems to provide very little access to Bitmap or even String resources.
class MoonPixels {
    private var pixelData as Array<Number>;
    private var smasher as MoonPixelSmasher;

    public function initialize() {
        pixelData = WatchUi.loadResource(Rez.JsonData.moonPixels) as Array<Number>;
        smasher = new MoonPixelSmasher();
    }

    // Get the brightness at some location.
    // TODO: interpolate?
    // Result is between 0 and 1, or null if the point is outside the disk.
    public function getPolar(r as Decimal, theta as Decimal) as Decimal? {
        var y = Math.round((SIZE/2)*r*Math.sin(theta)).toNumber();
        var x = Math.round((SIZE/2)*r*Math.cos(theta)).toNumber();
        return getRectangular(x, y);
    }

    // Draw some rows of the moon's face, at the given location and size, as specified by angle,
    // fraction, and phase.
    //
    // The amount of work done on any single call is limited to avoid exceeding the limit on
    // execution time for a watch face. If drawing isn't completed, the result contains the
    // next row to be drawn, which can be passed in fromRow to a later call to continue drawing
    // where it left off.
    public function draw(dc as Graphics.Dc, centerX as Number, centerY as Number, radius as Number,
                         parallacticAngle as Decimal, illuminationFraction as Decimal, phase as Decimal,
                         fromRow as Number?) as Number? {

        var calc = new MoonFaceCalculator(radius, parallacticAngle, illuminationFraction, phase);
        var writer = new MoonPixelRowWriter(dc, centerX, centerY, radius, smasher);

        var startRow = fromRow != null ? fromRow : -radius;
        for (var y = startRow; y <= radius; y += 1) {
            calc.setRow(y);
            writer.setRow(y);

            // Each row must have some pixels at either left or right edge, possibly both.
            // Start at each end and go until a non-illuminated pixel is found, or all pixels are
            // seen.

            // First check the left edge and scan left-to-right if needed:
            var left = calc.illuminated(calc.minX);
            var maxTested = calc.minX;
            if (left) {
                writer.setPixel(calc.minX, getRectangular(calc.mx.toNumber(), calc.my.toNumber()));

                var x;
                for (x = calc.minX+1; x <= calc.maxX; x += 1) {
                    if (calc.illuminated(x)) {
                        writer.setPixel(x, getRectangular(calc.mx.toNumber(), calc.my.toNumber()));
                    }
                    else {
                        break;
                    }
                }
                maxTested = x;
            }

            // Now, if we haven't scanned the entire row yet, scan back from the right:
            if (maxTested < calc.maxX) {
                var right = calc.illuminated(calc.maxX);
                if (right) {
                    writer.setPixel(calc.maxX, getRectangular(calc.mx.toNumber(), calc.my.toNumber()));

                    // System.println(Lang.format("Right arm needed: y=$1$, maxTested: $2$", [y, maxTested]));

                    var x;
                    for (x = calc.maxX-1; x >= maxTested; x -= 1) {
                        if (calc.illuminated(x)) {
                            writer.setPixel(x, getRectangular(calc.mx.toNumber(), calc.my.toNumber()));
                        }
                        else {
                            break;
                        }
                    }
                }
            }

            writer.commitRow();

            // Check the remaining execution time budget after each row. Using the actual clock
            // hopefully means that we can draw as much as possible in any given frame, depending
            // on what other work might have been done. But always leave some margin for any
            // other tasks that are going to follow.
            if (y-startRow > MAX_ROWS_PER_UPDATE or moonfaceApp.throttle.getRemainingTime() < 0.33) {
                System.println(Lang.format("Aborting drawing at row $1$ (radius: $2$) (out of time)", [y, radius]));
                return y;
            }
        }

        return null;
    }

    // Get the value, if any, for a point given in rectagular coords from the center of the disk.
    // Returns a value between 0.0 and 1.0, or null if the point is outside the disk.
    private function getRectangular(x as Number, y as Number) as Float? {
        // Note: as near as I can tell, local variables don't cost anything at runtime, but
        // accessing any member or static variable does, adding up to about 15% of the time
        // for drawing. Meanwhile, Monkey C doesn't seem to have #define or any other compile-time
        // constants.
        // Correction: there is `const` as an alternative to `var`, but it's not clear that it
        // has better performance, or even that it can handle these definitions.
        // So all the constants are re-defined here as locals:

        var local_SIZE = 128;
        var local_HALF_SIZE = 64;
        var local_PIXELS_PER_WORD = 5;
        var local_BITS_PER_PIXEL = 6;
        var local_PIXEL_MASK = 0x3f;   // (1 << BITS_PER_PIXEL) - 1;
        var local_WORDS_PER_ROW = 26;  // (128 + 5-1)/5;
        var local_MAX_VALUE = 63.0;    // PIXEL_MASK.toFloat();

        // Uncomment to verify integrity:
        // Test.assertEqual(local_SIZE,            SIZE);
        // Test.assertEqual(local_PIXELS_PER_WORD, PIXELS_PER_WORD);
        // Test.assertEqual(local_BITS_PER_PIXEL,  BITS_PER_PIXEL);
        // Test.assertEqual(local_PIXEL_MASK,      PIXEL_MASK);
        // Test.assertEqual(local_WORDS_PER_ROW,   WORDS_PER_ROW);
        // Test.assertEqual(local_MAX_VALUE,       MAX_VALUE);

        var rowIdx = local_HALF_SIZE + y;
        var colIdx = local_HALF_SIZE + x;

        // Not: ideally not needed given the check on radius in the caller, and actually costs ~25% of the time!?
        if (rowIdx < 0 or rowIdx >= local_SIZE or colIdx < 0 or colIdx >= local_SIZE) {
            return null;
        }

        var wordIdx = (colIdx / local_PIXELS_PER_WORD).toNumber();
        var offset = (colIdx % local_PIXELS_PER_WORD)*local_BITS_PER_PIXEL;

        var raw = (pixelData[rowIdx*local_WORDS_PER_ROW + wordIdx] >> offset) & local_PIXEL_MASK;
        if (raw == 0) {
            return null;
        }
        else {
            return raw / local_MAX_VALUE;
        }
    }
}

// Collect values for a row of pixels at a time, so they can (eventually) be written as a batch.
//
// TODO: encapsulate dithering state here; the same instance should be used to write one row,
// then advanced to the next.
class MoonPixelRowWriter {
    private var dc as Graphics.Dc;
    private var centerX as Number;
    private var centerY as Number;
    private var radius as Number;
    private var smasher as MoonPixelSmasher;

    // cached values:
    private var width;

    // state:
    private var y as Number = 0;
    private var values as Array<Float?>;
    private var errors as Array<Float?>;

    function initialize(dc as Graphics.Dc, centerX as Number, centerY as Number, radius as Number, smasher as MoonPixelSmasher) {
        self.dc = dc;
        self.centerX = centerX;
        self.centerY = centerY;
        self.radius = radius;
        self.smasher = smasher;

        width = 2*radius + 3;

        values = new Array<Float?>[width];
        errors = new Array<Float?>[width];
    }

    function setRow(y as Number) as Void {
        self.y = y;
        for (var i = 0; i < width; i += 1) {
            values[i] = null;
        }
    }

    function setPixel(x as Number, val as Float?) as Void {
        values[radius+x] = val;
    }

    function commitRow() as Void {
        // Error diffused to the next pixel to the right.
        var nextError = consumeError(-radius);

        // Note: any error that gets diffused to a pixel that doesn't have a value
        // just gets ignored. That means the image has sharp boundaries, but some
        // contrast might be lost. In theory, that error could be attributed to
        // the nearest illuminated pixel, but probably it's not noticeable anyway.

        for (var x = -radius; x <= radius; x += PIXELS_PER_CHAR) {
            var bits0 = 0;
            var bits1 = 0;
            var bits2 = 0;
            var bits3 = 0;

            for (var b = 0; b < PIXELS_PER_CHAR and (x + b) <= radius; b += 1) {
                var val = values[radius + (x + b)];
                if (val != null) {
                    val += nextError;

                    var bit = 1 << b;
                    var error;
                    if (val > 0.75) {
                        bits3 |= bit;  // white
                        error = val - 1;
                    }
                    else if (val > 0.50) {
                        bits2 |= bit;  // light gray
                        error = val - 0.67;
                    }
                    else if (val > 0.25) {
                        bits1 |= bit;  // dark gray
                        error = val - 0.33;
                    }
                    else {
                        bits0 |= bit;  // black
                        error = val - 0.0;
                    }

                    // Diffuse residual value to four neighboring pixels:

                    // The pixel on the right gets error from the previous row, and from this pixel:
                    nextError = consumeError(x + 1) + error*7.0/16;

                    // Accumulate some error in the buffer to be used when the next row is committed:
                    accumulateError(x - 1, error, 3.0/16);
                    accumulateError(x,     error, 5.0/16);
                    accumulateError(x + 1, error, 1.0/16);
                }
            }
            // Note: up to four setColor/drawText calls for each 6 pixels isn't so promising.
            // Reducing that would mean building a different array and string for each color and row.
            if (bits0 != 0) {
                smasher.drawPixels(dc, centerX + x, centerY + y, Graphics.COLOR_BLACK, bits0);
            }
            if (bits1 != 0) {
                smasher.drawPixels(dc, centerX + x, centerY + y, Graphics.COLOR_DK_GRAY, bits1);
            }
            if (bits2 != 0) {
                smasher.drawPixels(dc, centerX + x, centerY + y, Graphics.COLOR_LT_GRAY, bits2);
            }
            if (bits3 != 0) {
                smasher.drawPixels(dc, centerX + x, centerY + y, Graphics.COLOR_WHITE, bits3);
            }
        }
    }

    // Lookup the error from the pixels above, and clear it so it can be re-used.
    private function consumeError(x as Number) as Float {
        var idx = radius + x + 1;
        var err = errors[idx];
        errors[idx] = null;
        return err != null ? err : 0.0;
    }

    // Add some diffused error to one of the pixels below the current row.
    private function accumulateError(x as Number, error as Float, weight as Float) as Void {
        var idx = radius + x + 1;
        var prev = errors[idx];
        if (prev == null) { prev = 0.0; }
        errors[idx] = prev + error*weight;
    }

    // Note: tried using four Longs as bit vectors to hold pixels, then making only
    // one setColor call per row. It added 30% to the total frame onUpdate() time.
    // Presumably Longs are just super not-optimized; possibly always boxed, judging by
    // the Memory view.
    // Maybe try using an Array<Number> instead? That's cleaner in memory, but more importantly
    // maybe bitwise ops are faster.
}

// Draws up to 6 pixels at once, using one of 64 pre-allocated strings and our custom font.
//
// Note: a single instance should be allocated and cached, to avoid the overhead of repeated
// initialization.
class MoonPixelSmasher {
    private var font as FontReference;
    private var strs as Array<String>;

    function initialize() {
        font = WatchUi.loadResource(Rez.Fonts.Pixels) as FontReference;

        strs = new Array<String>[NUM_PIXEL_CHARS];
        for (var i = 0; i < NUM_PIXEL_CHARS; i += 1) {
            // Avoid the ASCII control characters (in particular, "\n")
            var codePoint = 0x20 + i;

            strs[i] = codePoint.toChar().toString();
        }
    }

    function drawPixels(dc as Dc, left as Number, y as Number, color as ColorValue, pixels as Number) {
        dc.setColor(color, -1);
        dc.drawText(left, y, font, strs[pixels], Graphics.TEXT_JUSTIFY_LEFT);
    }
}

// Geometry to figure out which pixels need to be drawn, based on a particular rotation and phase
// of the moon.
//
// Note: there's overhead in the VM to access object fields, as well as to call the methods,
// but hopefully this will allow for an improved algorithm (i.e. binary search).
class MoonFaceCalculator {
    // var radius as Number;
    // var parallacticAngle as Decimal;
    // var illuminationFraction as Decimal;
    // var phase as Decimal;

    private var t11 as Float;
    private var t21 as Float;
    private var rsq as Float;

    private var drawRight as Boolean;
    private var drawCenter as Boolean;
    private var drawLeft as Boolean;

    private var asq as Float;
    private var bsq as Float;
    private var absq as Float;

    private var y as Number;
    // private var x as Number;

    //
    // Visible to the caller:
    //

    // Coords of the current point, in image space:
    public var mx as Float;
    public var my as Float;

    // Minumum and maximum x-coords for the row, based on the circular disk only (not the current phase):
    public var minX as Number;
    public var maxX as Number;

    function initialize(radius as Number, parallacticAngle as Decimal, illuminationFraction as Decimal, phase as Decimal) {
        var scale = (SIZE/2)/radius.toFloat();
        t11 = (Math.cos(-parallacticAngle)*scale).toFloat();
        t21 = (Math.sin(-parallacticAngle)*scale).toFloat();
        rsq = (radius*radius).toFloat();

        // Half the minor axis of an ellipse defining the edge of the illuminated part of the moon.
        // Note: I suspect an ellipse isn't actually quite the correct shape, but at this resolution
        // it's probably close enough.
        var a;
        if (illuminationFraction < 0.5) {
            // Just trying the get this approximately realistic:
            // - some sliver of the moon visible except within ~24 hours of the new moon.
            a = (SIZE/2 - 4)*(1 - 2*illuminationFraction);
            // System.println(Lang.format("a: $1$", [a]));
        } else {
            a = (SIZE/2 - 4)*(2*illuminationFraction - 1);
            // System.println(Lang.format("(-)a: $1$", [a]));
        }
        drawRight = phase <= 0.5;
        drawCenter = 0.25 < phase and phase < 0.75;  // ?
        drawLeft = phase >= 0.5;
        // System.println(Lang.format("$1$; $2$; $3$", [drawLeft, drawCenter, drawRight]));

        var b = SIZE/2;
        asq = (a*a).toFloat();
        bsq = (b*b).toFloat();
        absq = asq*bsq;

        y = 0;
        mx = 0.0;
        my = 0.0;
        minX = 0;
        maxX = 0;
    }

    function setRow(y as Number) as Void {
        self.y = y;

        // Note: effectively, truncating the real value to an int seems to force it to lie
        // within the disk.
        maxX = Math.sqrt(rsq - y*y).toNumber();
        minX = -maxX;
    }

    // True if the pixel at (x, y) needs to be drawn. After this call, (mx, my) contains
    // image-space coords.
    function illuminated(x as Number) as Boolean {
        // This check is redundant if minX and maxX are used.
        // if (y*y + x*x > rsq) {
        //     // Skip some calculation; the point is clearly outside the disk
        //     return false;
        // }

        // Note: could save some multiplication by computing dx and dy once at
        // start of each row. But that's probably not where the time is at the moment.
        mx = x*t11 - y*t21;
        my = x*t21 + y*t11;

        // Is this pixel towards the center of the moon's image, relative to the ellipse
        // that defines the edge of the illuminated area?
        var inside = bsq*mx*mx + asq*my*my < absq;
        if (inside) {
            if (!drawCenter) {
                return false;
            }
        }
        else {
            if (mx < 0 and !drawLeft) {
                return false;
            }
            else if (mx > 0 and !drawRight) {
                return false;
            }
        }

        return true;
    }
}

(:test)
function testGetOne(logger as Logger) as Boolean {
    var mp = new MoonPixels();

    Test.assert(mp.getPolar(1.1, 0.0) == null);

    // Look at the middle pixel, but this is just the value I saw once:
    // assertApproximatelyEqual(mp.getPolar(0.0, 0.0), 0.47, 0.01, logger);  // 0.03?

    // Low-center is bright, more or less:
    // assertApproximatelyEqual(mp.getPolar(0.5, Math.PI*0.5), 0.70, 0.01, logger);  // 0.016?

    // Upper-left is dim, more or less:
    // assertApproximatelyEqual(mp.getPolar(0.5, -Math.PI*0.75), 0.33, 0.01, logger);  // 0.71?

    return true;
}


/*
Notes on encoding raw data for use in Monkey C:

No apparent way to access pixel data in images.

Use String to hold packed bytes, and decode them at runtime?
- what is the source encoding for String? Not documented.
- can load from JSON, which is less efficient than UTF-8, but decent
- can't extract a single char as a value
- toCharArray() -> array of (Unicode) chars
- toUtf8Array() -> array of bytes (in boxed 32-bit ints)
- substring() -> hopefully doesn't copy the buffer?

JSON-encoded chars:
- clean: 32-127 only (95 values)
- everything else is 6 bytes per character: "\u0000"
- maybe two values per byte in base 8 (ala base64) or 9 (0-8)?
- or two values per byte in base 10, using just a few of the ugly
- or just scale the pixels to the range 0-95?
- integers do get unpacked to Number (32-bit) or Long (64), as needed
- same for Float/Double, by the way
- scary: too many digits for Long results in null
- annoying: changed json source doesn't get re-compiled
- 64 bits in a Long encodes to 19 or 20 chars (depending on sign); 8 bytes at 2.5x overhead
- or 9 7-bit values in 19 chars (never negative); 2.1x

9*7 bits in each Long
- 1919 Longs in a flat array
- looks like each Long ends up on the heap, taking 17 bytes (according to the Memory view)
- total of 33KB

5*6 bits in each Number
- 3327 Numbers in a flat array
- no memory usage reported for each Number, implying that they're embedded in the Array
  instead of pointers
- 16,655 bytes = 3327*5 + 20
- that's kinda nutty but apparently that's the deal
- seems like the best option for now


Simulator vs. device:
- draw time: 20-52ms in sim; 600ms on device
- "watchdog" will kill the face, based on opcode count; no obvious way to measure/estimate that
  from code. Currently using System.getTimer to approximate it, but it's not consistent across
  different devices.
*/