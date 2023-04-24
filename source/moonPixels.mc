import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Test;

// From the sample project
// typedef JsonResourceType as Numeric or String or Array<JsonResourceType> or Dictionary<String, JsonResourceType>;

// Access and draw the pixels of an image of the moon's face. The pixels are stored in a
// JSON-formatted resource, because we want to do our own scaling, dithering, and rotation,
// and the Toybox API seems to provide very little access to Bitmap or even String resources.
class MoonPixels {
    private static var SIZE as Number = 128;
    private static var BITS_PER_PIXEL as Number = 6;
    private static var PIXELS_PER_WORD as Number = 5;

    private static var WORDS_PER_ROW as Number = (SIZE + PIXELS_PER_WORD-1)/PIXELS_PER_WORD;
    private static var PIXEL_MASK as Number = (1 << BITS_PER_PIXEL) - 1;
    private static var MAX_VALUE as Float = (1 << BITS_PER_PIXEL) - 1.0;

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

    // TODO: illumination as fraction/angle/what?
    public function draw(dc as Graphics.Dc, centerX as Number, centerY as Number, radius as Number, parallacticAngle as Decimal) as Void {
        // TODO: uh, dither?

        // System.println(Lang.format("angle: $1$", [parallacticAngle]));

        var cos = Math.cos(-parallacticAngle);
        var sin = Math.sin(-parallacticAngle);
        var scale = 64.0/radius;

        for (var y = -radius; y <= radius; y += 1) {
            for (var x = -radius; x <= radius; x += 1) {
                var val;
                if (y*y + x*x > radius*radius) {
                    // Skip some calculation; the point is clearly outside the disk
                    val = null;
                }
                else {
                    // Note: could save some multiplication by computing dx and dy once at
                    // start of each row. But that's probably not where the time is at the moment.
                    var mx = (x*cos - y*sin)*scale;
                    var my = (x*sin + y*cos)*scale;
                    // TOD0: round/interpolate?
                    val = getRectangular(mx.toNumber(), my.toNumber());
                }
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
                    drawPoint(dc, color, centerX + x, centerY + y);
                }
            }
        }
    }

    // Note: this is factored out mostly so the profiler can record it.
    private function drawPoint(dc as Dc, color as ColorType, x as Number, y as Number) as Void {
        dc.setColor(color, -1);
        dc.drawPoint(x, y);
    }

    // Get the value, if any, for a point given in rectagular coords from the center of the disk.
    // Returns a value between 0.0 and 1.0, or null if the point is outside the disk.
    private function getRectangular(x as Number, y as Number) as Decimal? {
        var rowIdx = (SIZE/2 + y).toNumber();
        var colIdx = (SIZE/2 + x).toNumber();
        if (rowIdx < 0 or rowIdx >= SIZE or colIdx < 0 or colIdx >= SIZE) {
            return null;
        }
        // System.println(Lang.format("$1$; $2$", [rowIdx, colIdx]));

        var wordIdx = (colIdx / PIXELS_PER_WORD).toNumber();
        var offset = (colIdx % PIXELS_PER_WORD)*BITS_PER_PIXEL;
        // System.println(Lang.format("$1$; $2$", [wordIdx, offset]));

        var foo = rowIdx*WORDS_PER_ROW + wordIdx;
        // System.println(Lang.format("$1$; $2$", [foo, pixelData.size()]));

        // return 0.5;
        // System.println(Lang.format("$1$", [pixelData[foo]]));

        // // System.println(pixelData);

        var raw = (pixelData[foo] >> offset) & PIXEL_MASK;
        if (raw == 0) {
            return null;
        }
        else {
            return raw / MAX_VALUE;
        }
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
*/