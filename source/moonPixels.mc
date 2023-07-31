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
        Rez.Drawables.Moon35_00,
        Rez.Drawables.Moon35_01,
        Rez.Drawables.Moon35_02,
        Rez.Drawables.Moon35_03,
        Rez.Drawables.Moon35_04,
        Rez.Drawables.Moon35_05,
        Rez.Drawables.Moon35_06,
        Rez.Drawables.Moon35_07,
        Rez.Drawables.Moon35_08,
        Rez.Drawables.Moon35_09,
        Rez.Drawables.Moon35_10,
        Rez.Drawables.Moon35_11,
        Rez.Drawables.Moon35_12,
        Rez.Drawables.Moon35_13,
        Rez.Drawables.Moon35_14,
        Rez.Drawables.Moon35_15,
        Rez.Drawables.Moon35_16,
        Rez.Drawables.Moon35_17,
        Rez.Drawables.Moon35_18,
        Rez.Drawables.Moon35_19,
        Rez.Drawables.Moon35_20,
        Rez.Drawables.Moon35_21,
        Rez.Drawables.Moon35_22,
        Rez.Drawables.Moon35_23,
        Rez.Drawables.Moon35_24,
        Rez.Drawables.Moon35_25,
        Rez.Drawables.Moon35_26,
        Rez.Drawables.Moon35_27,
        Rez.Drawables.Moon35_28,
        Rez.Drawables.Moon35_29,
        Rez.Drawables.Moon35_30,
        Rez.Drawables.Moon35_31,
        Rez.Drawables.Moon35_32,
        Rez.Drawables.Moon35_33,
        Rez.Drawables.Moon35_34,
        Rez.Drawables.Moon35_35,
        Rez.Drawables.Moon35_36,
        Rez.Drawables.Moon35_37,
        Rez.Drawables.Moon35_38,
        Rez.Drawables.Moon35_39,
        Rez.Drawables.Moon35_40,
        Rez.Drawables.Moon35_41,
        Rez.Drawables.Moon35_42,
        Rez.Drawables.Moon35_43,
        Rez.Drawables.Moon35_44,
        Rez.Drawables.Moon35_45,
        Rez.Drawables.Moon35_46,
        Rez.Drawables.Moon35_47,
        Rez.Drawables.Moon35_48,
        Rez.Drawables.Moon35_49,
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
        rotate90.translate(1.0*nativeRadius, 1.0*nativeRadius);
        rotate90.rotate(Math.PI/2);
        rotate90.translate(-1.0*nativeRadius, -1.0*nativeRadius);

        rotate180 = new AffineTransform();
        rotate180.translate(1.0*nativeRadius, 1.0*nativeRadius);
        rotate180.rotate(Math.PI);
        rotate180.translate(-1.0*nativeRadius, -1.0*nativeRadius);

        rotate270 = new AffineTransform();
        rotate270.translate(1.0*nativeRadius, 1.0*nativeRadius);
        rotate270.rotate(Math.PI*3/2);
        rotate270.translate(-1.0*nativeRadius, -1.0*nativeRadius);
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
        clearShadow2(bufferDc, radius, adjustedAngle, illuminationFraction, phase);

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

                // Note: clear all the way to the left edge, just in case there are any stray
                // pixels in the source image (because there are).
                var firstDarkX = -radius;

                // Similarly, if the entire row is dark, and make sure to clear all the way to the
                // right edge.
                var lastDarkX = calc.lastNonIlluminated(calc.minX, calc.maxX);
                if (lastDarkX == calc.maxX) {
                    lastDarkX = radius;
                }

                dc.setClip(radius + firstDarkX, radius + y, lastDarkX - firstDarkX, 1);
                dc.clear();
            }
            else if (!calc.illuminated(calc.maxX)) {
                // Some pixels on the right are dark:
                // Note: in this case, we know that minX is not dark.

                var firstDarkX = calc.lastIlluminated(calc.minX, calc.maxX) + 1;

                // Note: clear all the way to the right edge, just in case there are any stray
                // pixels in the source image (because there are).
                var lastDarkX = radius;

                dc.setClip(radius + firstDarkX, radius + y, lastDarkX - firstDarkX, 1);
                dc.clear();
            }
            else if (!calc.illuminated(0)) {
                // Some pixels in the middle are dark (i.e. a rotated crescent):
                // Note: we know minX and maxX are not dark

                // FIXME: currently adding an extra pixel on either side to reduce jaggies, but
                // this is probably too much, meaning there's never any true new moon.
                var firstDarkX = calc.lastIlluminated(calc.minX, 0) + 2;
                var lastDarkX = calc.lastNonIlluminated(0, calc.maxX) - 1;

                dc.setClip(radius + firstDarkX, radius + y, lastDarkX - firstDarkX, 1);
                dc.clear();
            }
        }

        dc.clearClip();
    }

    // Adapted from "Integer-based Algorithm for Drawing Ellipses" (Eberly, 1999).
    private function clearShadow2(dc as Dc, radius as Number,
                        parallacticAngle as Decimal, illuminationFraction as Decimal, phase as Decimal) as Void {
        // var lefts = new Array<Number?>[2*radius];
        // var rights = new Array<Number?>[2*radius];

        // Note: the y-axis is reversed on the display from the terms used here, so "up" means
        // increasing y, which is actually down on the screen.

        // Note: this algorithm draws pixels that are definitely outside the ellipse. Probably want
        // to account for that by erasing to the inside edge of the traced outline.

        // xa, ya: axis in the first quadrant (xa > 0, ya >= 0), with xa >= ya
        // xb, yb: axis in the second quadrant

        var majorAxis = (radius + 0.5).toDouble();
        var xa = -Math.sin(parallacticAngle)*majorAxis;
        var ya = Math.cos(parallacticAngle)*majorAxis;

        // Choose minor axis, avoiding very small values which could trigger edge cases:
        var minorAxis = majorAxis*(2*illuminationFraction - 1).abs();
        if (minorAxis < 1.0) { minorAxis = 1.5d; }
        var xb = Math.cos(parallacticAngle)*minorAxis;
        var yb = Math.sin(parallacticAngle)*minorAxis;

        // Choose coords such that ya and yb >= 0:
        if (ya < 0) { xa = -xa; ya = -ya; }
        if (yb < 0) { xb = -xb; yb = -yb; }
        // ... and xa > 0:
        if (xa < 0) {
            var tmp;
            tmp = xa; xa = xb; xb = tmp;
            tmp = ya; ya = yb; yb = tmp;
        }

        // dc.setColor(Graphics.COLOR_RED, -1);
        // dc.drawPoint(radius + xa, radius + ya);
        // // dc.drawPoint(radius - xa, radius - ya);
        // dc.setColor(Graphics.COLOR_BLUE, -1);
        // dc.drawPoint(radius + xb, radius + yb);
        // // dc.drawPoint(radius - xb, radius - yb);


        // The ellipse is points (x,y) where Ax^2 + 2Bxy + Cy^2 - D = 0
        // Tricky: x(y)a(b) can be small, but not all of them. Using Double for eveything
        // avoids any early rounding. At the end, convert everything to Float, which the
        // VM handles more efficiently than Long. The paper uses 64-bit integers, because
        // we don't need any precision past the decimal point, but it was written when
        // floating-point wasn't cheap the way it probably is now.
        var asq = xa*xa + ya*ya;
        var asqs = asq*asq;
        var bsq = xb*xb + yb*yb;
        var bsqs = bsq*bsq;
        var A = (xa*xa*bsqs + xb*xb*asqs).toFloat();
        var B = (xa*ya*bsqs + xb*yb*asqs).toFloat();
        var C = (ya*ya*bsqs + yb*yb*asqs).toFloat();
        var D = (asqs*bsqs).toFloat();
        // System.println(Lang.format("($1$, $2$); ($3$, $4$)", [xa, ya, xb, yb]));
        // System.println(Lang.format("$1$; $2$; $3$; $4$", [A/2.15e9, B/2.15e9, C/2.15e9, D/2.15e9]));

        // TEMP:
        dc.setColor(Graphics.COLOR_GREEN, -1);

        if ((A == 0.0 and B == 0.0) or (C == 0.0 and D == 0.0)) {
            System.println("Zero coefficients! Skip for now");
        }
        // else if (xa == 0) {
        //     System.println("xa is 0. Skip for now");
        //     // Axis-aligned:
        //     // Necessary because zero coefficients create infinite loops?
        // }
        else {
            var x = Math.round(-xa).toNumber();
            var y = Math.round(-ya).toNumber();
            var dx = B*x + C*y;
            var dy = -(A*x + B*y);

            // System.println(Lang.format("dx: $1$", [dx]));

            // First advance to a point where the magnitude of slope is >= 1, without
            // recording any pixels:
            if (x > y) {
                // Arc 0: (-xa, -ya) left and maybe up until the slope is -1; x-- (y++)
                while (-dy > dx) {
                    // dc.drawPoint(radius + x, radius + y);
                    // dc.drawPoint(radius - x, radius - y);

                    // Choose between (x-1, y) and (x-1, y+1).
                    // Test (x-1, y+1); if inside, then go to (x-1, y), otherwise (x-1, y+1)
                    x -= 1;
                    var sigma = A*x*x + 2*B*x*(y+1) + C*(y+1)*(y+1) - D;
                    if (sigma >= 0) {
                        dx += C;
                        dy -= B;
                        y += 1;
                    }
                    dx -= B;
                    dy += A;
                }
            }

            // Arc 1: up and maybe left until the tangent is vertical; y++ (x--)
            while (dx <= 0) {
                dc.drawPoint(radius + x, radius + y);
                dc.drawPoint(radius - x, radius - y);

                // Choose between (x, y+1) and (x-1, y+1).
                // Test (x, y+1); if inside, then go to (x-1, y+1), otherwise (x, y+1)
                y += 1;
                var sigma = A*x*x + 2*B*x*y + C*y*y - D;
                if (sigma < 0) {
                    dx -= B;
                    dy += A;
                    x -= 1;
                }
                dx += C;
                dy -= B;
            }

            // Arc 2: up and maybe right until slope = 1; y++ (x++)
            while (dy > dx) {
                dc.drawPoint(radius + x, radius + y);
                dc.drawPoint(radius - x, radius - y);

                // Choose between (x, y+1) and (x+1, y+1).
                // Test (x+1, y+1); if inside, then go to (x, y+1), otherwise (x+1, y+1)
                y += 1;
                var sigma = A*(x+1)*(x+1) + 2*B*(x+1)*y + C*y*y - D;
                if (sigma >= 0) {
                    dx += B;
                    dy -= A;
                    x += 1;
                }
                dx += C;
                dy -= B;
            }

            // Arc 3: right and maybe up until tangent is horizontal; x++ (y++)
            // dc.setColor(Graphics.COLOR_ORANGE, -1);
            while (dy >= 0) {
                dc.drawPoint(radius + x, radius + y);
                dc.drawPoint(radius - x, radius - y);

                // Choose between (x+1, y) and (x+1, y+1).
                // Test (x+1, y); if inside, then go to (x+1, y+1), otherwise (x+1, y)
                x += 1;
                var sigma = A*x*x + 2*B*x*y + C*y*y - D;
                if (sigma < 0) {
                    dx += C;
                    dy -= B;
                    y += 1;
                }
                dx += B;
                dy -= A;
            }

            // Arc 4: right and maybe down until the slope is -1; x++ (y--)
            // dc.setColor(Graphics.COLOR_PINK, -1);
            while (-dy < dx) {
                dc.drawPoint(radius + x, radius + y);
                dc.drawPoint(radius - x, radius - y);

                // Choose between (x+1, y) and (x+1, y-1).
                // Test (x+1, y-1); if inside, then go to (x+1, y), otherwise (x+1, y-1)
                x += 1;
                var sigma = A*x*x + 2*B*x*(y-1) + C*(y-1)*(y-1) - D;
                if (sigma > 0) {
                    dx -= C;
                    dy += B;
                    y -= 1;
                }
                dx += B;
                dy -= A;
            }

            // Arc 5: down and maybe right until (xa, ya); y-- (x++)
            while (y > ya) {
                dc.drawPoint(radius + x, radius + y);
                dc.drawPoint(radius - x, radius - y);

                // Choose between (x, y-1) and (x+1, y-1).
                // Test (x, y-1); if inside, then go to (x+1, y-1), otherwise (x, y-1)
                y -= 1;
                var sigma = A*x*x + 2*B*x*y + C*y*y - D;
                if (sigma < 0) {
                    dx += B;
                    dy -= A;
                    x += 1;
                }
                dx -= C;
                dy += B;
            }
        }
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



// function

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

    // Binary search to find the greatest x between lo and hi, inclusive, such that
    // calc.illuminated(x) is false.
    // Assumptions: the pixels between lo and hi form a single (possibly empty) non-illuminated
    // region on the left, followed by a single (possibly empty) illuminated region on the right.
    // If there are any extraneous pixels, the result could be just a random non-illuminated
    // pixel.
    function lastNonIlluminated(lo as Number, hi as Number) as Number {
        // invariant: !calc.illuminated(lo) (assumed, at the start)

        // Short-circuit this relatively common case, to produce the right result
        // and keep the calculation of mid simple within the loop.
        if (!illuminated(hi)) {
            return hi;
        }

        while (hi > lo+1) {
            var mid = (lo + hi)/2;  // Tricky: when both are < 0 and 1 apart, this truncates to hi
            if (!illuminated(mid)) {
                lo = mid;
            }
            else {
                hi = mid;
            }
        }
        return lo;
    }

    // Binary search to find the least x between lo and hi, inclusive, such that
    // calc.illuminated(x) is false.
    // Assumptions: the pixels between lo and hi form a single (possibly empty) illuminated region
    // on the left, followed by a single (possibly empty) non-illuminated region on the right.
    // If there are any extraneous pixels, the result could be just a random *illuminated*
    // pixel.
    function lastIlluminated(lo as Number, hi as Number) as Number {
        // invariant: calc.illuminated(lo) (assumed, at the start)

        while (hi > lo+1) {
            var mid = (lo + hi)/2;  // Tricky: when both are < 0 and 1 apart, this truncates to hi
            if (illuminated(mid)) {
                lo = mid;
            }
            else {
                hi = mid;
            }
        }
        return hi;
    }

}

(:test)
function testGetOne(logger as Logger) as Boolean {
    // var mp = new MoonPixels();

    // Test.assert(mp.getPolar(1.1, 0.0) == null);

    // Look at the middle pixel, but this is just the value I saw once:
    // assertApproximatelyEqual(mp.getPolar(0.0, 0.0), 0.47, 0.01, logger);  // 0.03?

    // Low-center is bright, more or less:
    // assertApproximatelyEqual(mp.getPolar(0.5, Math.PI*0.5), 0.70, 0.01, logger);  // 0.016?

    // Upper-left is dim, more or less:
    // assertApproximatelyEqual(mp.getPolar(0.5, -Math.PI*0.75), 0.33, 0.01, logger);  // 0.71?

    return true;
}
