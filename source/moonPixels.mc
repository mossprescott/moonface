import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Test;

const SIZE as Number = 128;
const BITS_PER_PIXEL as Number = 6;
const PIXELS_PER_WORD as Number = 5;

const WORDS_PER_ROW as Number = (SIZE + PIXELS_PER_WORD-1)/PIXELS_PER_WORD;
const PIXEL_MASK as Number = (1 << BITS_PER_PIXEL) - 1;
const MAX_VALUE as Float = (1 << BITS_PER_PIXEL) - 1.0;

// A limit on the total amount of points to ever draw in a single cycle, to avoid
// running into the execution time limit. No way to come up with a precise figure,
// this is the result of a little trial and error.
const MAX_PLOTTED as Number = 600;

// Access and draw the pixels of an image of the moon's face. The pixels are stored in a
// JSON-formatted resource, because we want to do our own scaling, dithering, and rotation,
// and the Toybox API seems to provide very little access to Bitmap or even String resources.
class MoonPixels {
    private var pixelData as Array<Number>;

    public function initialize() {
        pixelData = WatchUi.loadResource(Rez.JsonData.moonPixels) as Array<Number>;
    }

    // Get the brightness at some location.
    // TODO: interpolate?
    // Result is between 0 and 1, or null if the point is outside the disk.
    public function getPolar(r as Decimal, theta as Decimal) as Decimal? {
        var y = Math.round(64*r*Math.sin(theta)).toNumber();
        var x = Math.round(64*r*Math.cos(theta)).toNumber();
        return getRectangular(x, y);
    }

    // // Get the brightness at some location.
    // // TODO: interpolate?
    // // Result is between 0 and 1, or null if the point is outside the disk.
    // public function getPolar(r as Decimal, theta as Decimal) as Decimal? {
    //     var y = Math.round((SIZE/2)*r*Math.sin(theta)).toNumber();
    //     var x = Math.round((SIZE/2)*r*Math.cos(theta)).toNumber();
    //     return getRectangular(x, y);
    // }

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
        // TODO: uh, dither?

        var calc = new MoonFaceCalculator(radius, parallacticAngle, illuminationFraction, phase);

        var lastColor = 0xFFFFFF;
        var plottedCount = 0;

        var startRow = fromRow != null ? fromRow : -radius;
        for (var y = startRow; y <= radius; y += 1) {
            calc.setRow(y);

            // TODO: each row must have some pixels at either left or right edge, possibly both.
            // Start at each end and go until a non-illuminated pixel is found, or all pixels are
            // seen.
            // var left = calc.illuminated(calc.minX);
            // var right = calc.illuminated(calc.maxX);
            // System.println(Lang.format("$1$; $2$: $3$; $4$: $5$", [y, calc.minX, left, calc.maxX, right]));

            var drewSome = false;

            for (var x = calc.minX; x <= calc.maxX; x += 1) {
                var val;

                // TEMP: count every pixel we look at
                plottedCount += 1;

                if (!calc.illuminated(x)) {
                    if (drewSome) { break; } // HACK: assume only one segment per row
                    else { continue; }
                }
                else {
                    // drewSome = true;
                }

                // TODO: round/interpolate?
                val = getRectangular(calc.mx.toNumber(), calc.my.toNumber());  // 16ms
                if (val != null) {
                    var color;
                    if (val > 0.75) {
                        color = 0xFFFFFF;  // white
                    }
                    else if (val > 0.50) {
                        color = 0xAAAAAA;  // light gray
                    }
                    else if (val > 0.25) {
                        color = 0x555555;  // dark gray
                    }
                    else {
                        color = 0x000000;  // black
                    }
                    // Note: setColor takes ~10% of the time, so avoid it when it's redundant:
                    if (color != lastColor) {
                        dc.setColor(color, -1);  // 4ms
                        lastColor = color;
                    }
                    dc.drawPoint(centerX + x, centerY + y);      // 7ms
                    // plottedCount += 1;

                    if (plottedCount >= MAX_PLOTTED) {
                        System.println(Lang.format("Aborting drawing at ($1$, $2$) (radius: $3$)", [x, y, radius]));
                        return y;
                    }
                }
            }
        }

        //System.println(Lang.format("plotted: $1$", [plottedCount]));

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

// function typeOf(obj as Object) as String {
//     if (obj == null) { return "<null>"; }
//     switch (obj) {
//         case instanceof String: return "String";
//         case instanceof Char: return "Char";
//         case instanceof Number: return "Number";
//         case instanceof Long: return "Long";
//         case instanceof Float: return "Float";
//         case instanceof Double: return "Double";
//         case instanceof Array: return "Array";
//         case instanceof Dictionary: return "Dictionary";
//         case instanceof Symbol: return "Symbol";
//         default: return "?";
//     }
// }

/*
Notes on encoding raw data for use in Monkey C:

No apparent way to access pixel data in images.

Array<Number> or Array<Long> (probably) means boxed integers, and lots of wasted space.

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


Current (dumb) option:
- 128x128 pixels
- simple, nested JSON arrays
- a Number between 0 and 99 at each pixel
- trimmed to remove all the empty pixels in the corners
- source JSON is about 30K
- adds about 65KB to the prg (78KB total)
- that's too big to load, so removed some rows
- for 92/128 rows: memory profiler says 52KB in memory for the nested array (655 bytes for each full row)

All these decoding options sound like lot of allocation of temporary arrays and boxed values,
but what choice are they giving me?

Simulator vs. device:
- draw time: 52ms in sim; 600ms on device
*/