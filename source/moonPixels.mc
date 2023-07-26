import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Test;

const MAX_ROWS_PER_UPDATE = 2;

// Access and draw the pixels of an image of the moon's face. The actual pixels are scaled,
// rotated, and dithered at a selection of angles so that they can be drawn relatively
// efficiently in whatever orientation is needed.
class MoonPixels {
    var bitmapKeys as Array<Symbol> = [
        Rez.Drawables.Moon30_00,
        Rez.Drawables.Moon30_01,
        Rez.Drawables.Moon30_02,
        Rez.Drawables.Moon30_03,
        Rez.Drawables.Moon30_04,
        Rez.Drawables.Moon30_05,
        Rez.Drawables.Moon30_06,
        Rez.Drawables.Moon30_07,
        Rez.Drawables.Moon30_08,
        Rez.Drawables.Moon30_09,
        Rez.Drawables.Moon30_10,
        Rez.Drawables.Moon30_11,
        Rez.Drawables.Moon30_12,
        Rez.Drawables.Moon30_13,
        Rez.Drawables.Moon30_14,
        Rez.Drawables.Moon30_15,
        Rez.Drawables.Moon30_16,
        Rez.Drawables.Moon30_17,
        Rez.Drawables.Moon30_18,
        Rez.Drawables.Moon30_19,
    ] as Array<Symbol>;

    var nativeRadius as Number;
    var stepAngle as Float;

    var savedBufferRef as BufferedBitmapReference?;

    var rotate90 as AffineTransform;
    var rotate180 as AffineTransform;
    var rotate270 as AffineTransform;

    function initialize() {
        nativeRadius = (WatchUi.loadResource(bitmapKeys[0]) as BitmapReference).getWidth()/2;

        // Angle in radians between one image and the next, always an even fraction of π/2. Within
        // any range of that size starting with the range centered at an angle of 0, the same
        // pixels will get drawn.
        stepAngle = (2*Math.PI)/(4*bitmapKeys.size());

        // Rotation transforms:
        //    cos, -sin,  tx
        //    sin,  cos,  ty
        // with translation as needed to rotate around the center point.
        //
        // Note: setting the elements manually with setMatrix results in weird scaling, even though
        // the values seem to be identical.

        rotate90 = new AffineTransform();
        rotate90.translate(30.0, 30.0);
        rotate90.rotate(Math.PI/2);
        rotate90.translate(-30.0, -30.0);

        rotate180 = new AffineTransform();
        rotate180.translate(30.0, 30.0);
        rotate180.rotate(Math.PI);
        rotate180.translate(-30.0, -30.0);

        rotate270 = new AffineTransform();
        rotate270.translate(30.0, 30.0);
        rotate270.rotate(Math.PI*3/2);
        rotate270.translate(-30.0, -30.0);
        // System.println(rotate270.getMatrix());
    }

    // The size for which drawing results in pixel-accurate dithering.
    function getNativeRadius() as Number {
        return nativeRadius;
    }

    // Draw the moon's face, at the given location and size, as specified by angle,
    // fraction, and phase.
    // The image is always drawn into an offscreen buffer and then copied to the destination.
    public function draw(dc as Graphics.Dc, centerX as Number, centerY as Number, radius as Number,
                         parallacticAngle as Decimal, illuminationFraction as Decimal, phase as Decimal) as Void {
        var buffer = getBuffer(radius);
        var bufferDc = buffer.getDc();

        // Start with a clean slate:
        bufferDc.setColor(-1, -1);
        bufferDc.clear();

        // Quantize the angle to match the pixels we drew. If the shadow falls differently across
        // them it's fairly noticeable, and we can always generate more images if we want smaller
        // angular increments. Rounding as opposed to truncating will make the jumps fall
        // more nicely.
        var adjustedAngle = stepAngle*Math.round(parallacticAngle/stepAngle);

        drawFullMoon(bufferDc, radius, adjustedAngle);

        clearShadow(bufferDc, radius, adjustedAngle, illuminationFraction, phase);

        //
        // Finally, copy the completed image to the destination:
        //
        dc.drawBitmap(centerX - radius, centerY - radius, buffer);

        // TEMP: verify placement
        // dc.setColor(Graphics.COLOR_RED, -1);
        // dc.drawCircle(centerX, centerY, radius);
    }

    // Draw the entire disk in the current orientation:
    private function drawFullMoon(dc as Dc, radius as Number, angle as Decimal) as Void {
        var turns = angle/(2*Math.PI);
        var turnFraction = turns - Math.floor(turns);

        var imgIndex = (turnFraction*4*bitmapKeys.size()).toNumber() % bitmapKeys.size();
        var rt;
        // System.println(Lang.format("turnFraction: $1$", [turnFraction]));
        if (turnFraction >= 0.75) {
            rt = rotate270;
        } else if (turnFraction >= 0.5) {
            rt = rotate180;
        } else if (turnFraction >= 0.25) {
            rt = rotate90;
        } else {
            rt = null;
        }

        var img = WatchUi.loadResource(bitmapKeys[imgIndex]) as BitmapReference;
        if (radius == nativeRadius) {
            if (rt == null) {
                dc.drawBitmap(0, 0, img);
            }
            else {
                dc.drawBitmap2(0, 0, img, { :transform => rt });
            }
        }
        else {
            // For other sizes (mostly smaller), draw the same pixels, scaled as needed.
            // This will spoil the dithering, but at small sizes it's not too noticeable
            // and that's what we're using it for.
            var st = new AffineTransform();
            var sf = 1.0*radius/nativeRadius;
            st.scale(sf, sf);
            if (rt != null) { st.concatenate(rt); }
            dc.drawBitmap2(0, 0, img, { :transform => st });
        }
    }

    // Erase portions of the moon's image that are currently in shadow.
    //
    // In each row, test to see which portion of the pixels is visible, and use binary search
    // to find the edge in image space. For skinny crescents, that reduces the number of
    // ellipse calculations from a max of O(2*radius) ~= 60 to about O(log(2*radius)) ~= 8
    // (plus an inevitable few per row).
    private function clearShadow(dc as Dc, radius as Number,
                        parallacticAngle as Decimal, illuminationFraction as Decimal, phase as Decimal) as Void {
        // Note: Dc.clear seems to be the only way to write transparent pixels over the top of
        // previous drawing. Although it seems like it might be expensive, it probably doesn't
        // compare to the actual geometry we're doing.

        var calc = new MoonFaceCalculator(radius, parallacticAngle, illuminationFraction, phase);

        for (var y = -radius; y < radius; y += 1) {
            calc.setRow(y);

            if (!calc.illuminated(calc.minX)) {
                // Some pixels on the left are dark:

                // Binary search to find the first visible pixel, if any:
                var lo = calc.minX;  // invariant: !calc.illuminated(lo)
                var hi = calc.maxX;
                while (hi > lo+1) {
                    var mid = (lo + hi)/2;  // Tricky: when both are < 0 and 1 apart, this truncates to hi
                    if (!calc.illuminated(mid)) {
                        lo = mid;
                    }
                    else {
                        hi = mid;
                    }
                }

                // Note: clear all the way to the left edge, just in case there are any stray
                // pixels in the source image (because there are).
                var firstDarkX = -radius;

                // Similarly, if the entire row is dark, and make sure to clear all the way to the
                // right edge.
                var lastDarkX;
                if (hi == calc.maxX) {
                    lastDarkX = radius;
                }
                else {
                    lastDarkX = lo;
                }

                dc.setClip(radius + firstDarkX, radius + y, lastDarkX - firstDarkX, 1);
                dc.clear();
            }
            else if (!calc.illuminated(calc.maxX)) {
                // Some pixels on the right are dark:
                // Note: in this case, we know that minX is not dark.

                // Binary search to find the last dark pixel:
                var lo = calc.minX;  // invariant: calc.illuminated(lo)
                var hi = calc.maxX;
                while (hi > lo+1) {
                    var mid = (lo + hi)/2;  // Tricky: when both are < 0 and 1 apart, this truncates to hi
                    if (calc.illuminated(mid)) {
                        lo = mid;
                    }
                    else {
                        hi = mid;
                    }
                }

                var firstDarkX = lo;
                // Note: clear all the way to the right edge, just in case there are any stray
                // pixels in the source image (because there are).
                var lastDarkX = radius;

                dc.setClip(radius + firstDarkX, radius + y, lastDarkX - firstDarkX, 1);
                dc.clear();
            }
            else if (!calc.illuminated(0)) {
                // Some pixels in the middle are dark (i.e. a rotated crescent):

                // TODO: search twice and erase in the middle
            }
        }

        dc.clearClip();
    }

    private function getBuffer(radius as Number) as BufferedBitmap {
        var size = radius*2;

        if (savedBufferRef != null) {
            var buffer = savedBufferRef.get() as BufferedBitmap?;
            if (buffer != null and buffer.getWidth() >= size) {
                return buffer;
            }
        }

        var newBufferRef = Graphics.createBufferedBitmap({
            :width => size, :height => size
        });
        var newBuffer = newBufferRef.get() as BufferedBitmap?;
        if (newBuffer != null) {
            savedBufferRef = newBufferRef;
            return newBuffer;
        }
        else {
            System.error("no buffer");
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
        // A bogus factor relative to which some pixel-level adjustments are made. Used to be the
        // size of the array of raw samples, not that that actually meant anything here.
        var SIZE = 128;

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
