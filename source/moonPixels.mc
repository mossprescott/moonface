using Toybox.Graphics;
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

    private var rows as Array<Array<Number>>;

    public function initialize() {
        rows = WatchUi.loadResource(Rez.JsonData.moonPixels) as Array<Array<Number>>;
    }

    // Get the brightness at some location.
    // TODO: interpolate?
    // Result is between 0 and 1, or null if the point is outside the disk.
    public function getPolar(r as Decimal, theta as Decimal) as Decimal? {
        // System.println(rows[0]);
        // System.println(rows[0][[2]]);  // error

        // var utf8full = (rows[0] as String).toUtf8Array();
        // System.println(utf8full[2]);  // 99

        // var substring = (rows[0] as String).substring(2, 3);
        // System.println(substring.length());  // 1
        // System.println(substring.toCharArray()[0].toNumber()); // 99

        // for (var i = 0; i < rows.size(); i += 1) {
        //     System.println(Lang.format("rows[$1$]: $2$, $3$", [i, rows[i], typeOf(rows[i])]));
        // }

        var y = Math.round(64*r*Math.sin(theta)).toNumber();
        var x = Math.round(64*r*Math.cos(theta)).toNumber();
        return getRectangular(x, y);
    }

    public function draw(dc as Graphics.Dc, centerX as Number, centerY as Number, radius as Number, parallacticAngle as Decimal) as Void {
        // TODO: uh, dither?

        for (var y = -radius; y <= radius; y += 2) {
            for (var x = -radius; x <= radius; x += 2) {
                // TODO: this, combined with the calculations in get(), is too darn slow.
                // Probably collapse some of it into this function and do only a single
                // sin/cos/whatever since there's only one angle of rotation involved.

                var r = Math.sqrt(y*y + x*x)/radius;
                var theta = Math.atan2(y, x) - parallacticAngle;
                var val = getPolar(r, theta);
                // // System.println(Lang.format("($1$, $2$); $3$", [x, y, r]));
                // var val = r <= 1 ? 1 : null;
                if (val != null) {
                    // System.println(Lang.format("($1$, $2$); $3$", [r, theta, val]));
                    if (val > 0.75) {
                        dc.setColor(Graphics.COLOR_WHITE, -1);
                    }
                    else if (val > 0.50) {
                        dc.setColor(Graphics.COLOR_LT_GRAY, -1);
                    }
                    else if (val > 0.25) {
                        dc.setColor(Graphics.COLOR_DK_GRAY, -1);
                    }
                    else {
                        dc.setColor(Graphics.COLOR_BLACK, -1);
                    }
                    dc.drawPoint(centerX + x, centerY + y);
                }
            }
        }
    }

    // Get the value, if any, for a point given in rectagular coords from the center of the disk.
    // Returns a value between 0.0 and 1.0, or null if the point is outside the disk.
    private function getRectangular(x as Number, y as Number) as Decimal? {
        var rowIdx = Math.round(64 + y).toNumber();
        if (rowIdx < 0 or rowIdx >= rows.size()) { return null; }
        var row = rows[rowIdx];

        var colIdx = Math.round(row.size()/2 + x).toNumber();
        if (colIdx < 0 or colIdx >= row.size()) { return null; }

        var rawVal = row[colIdx];

        return rawVal/99.0;
    }
}

(:test)
function testGetOne(logger as Logger) as Boolean {
    var mp = new MoonPixels();

    Test.assert(mp.getPolar(1.1, 0.0) == null);

    // Look at the middle pixel, but this is just the value I saw once:
    // assertApproximatelyEqual(mp.getPolar(0.0, 0.0), 0.47, 0.01, logger);

    // Low-center is bright, more or less:
    // assertApproximatelyEqual(mp.getPolar(0.5, Math.PI*0.5), 0.70, 0.01, logger);

    // Upper-left is dim, more or less:
    assertApproximatelyEqual(mp.getPolar(0.5, -Math.PI*0.75), 0.33, 0.01, logger);

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