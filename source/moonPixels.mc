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

        // System.println(Lang.format("angle: $1$; phase: $2$; fraction: $3$", [adjustedAngle, phase, illuminationFraction]));

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

    // Use a clever ellipse-tracing algorithm to find the pixels in each row that are on the border
    // of the ellipse which defines the edge of the shadow. Then some quick checks to determine
    // which part of each row — with respect to the ellipse boundary — needs to be erased.
    //
    // Adapted from "Integer-based Algorithm for Drawing Ellipses" (Eberly, 1999).
    //
    // Note: it would be a lot more readable to factor out all of the bumping/testing/recording into
    // small methods somewhere. Unfortunately, that's about 2x slower, according to the simulator's
    // profiler. That's plausible, because of all the method calls and member references. Keeping it
    // all in one ugly function means only fast local variable access, even though the code is larger
    // and uglier.
    private function clearShadow(dc as Dc, radius as Number,
                        parallacticAngle as Decimal, illuminationFraction as Decimal, phase as Decimal) as Void {

        // Note: the y-axis is reversed on the display from the terms used here, so "up" means
        // increasing y, which is actually down on the screen.

        // Note: this algorithm traces pixels that are definitely outside the ellipse. Probably want
        // to account for that by erasing to the inside edge of the traced outline.

        // Select a point on each axis such that:
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

        // The ellipse is points (x,y) where Ax^2 + 2Bxy + Cy^2 - D = 0
        // Tricky: x(y)a(b) can be small, but not all of them. Using Double for everything
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

        // We'll accumulate every x-coord we trace for each non-negative y coord, then reduce them
        // afterward. This isn't the most efficient way to store them, but it makes the repeated code
        // simple, and we know the total number of such coords is O(radius).
        var maxRow = radius+2;  // Not sure why we need this much margin, but otherwise we get overflow.
        var xsByRow = new Array<Array<Number>>[maxRow+1];
        for (var i = 0; i <= maxRow; i += 1) { xsByRow[i] = []; }

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
                if (y >= 0) { xsByRow[ y].add( x); }
                if (y <= 0) { xsByRow[-y].add(-x); }

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
                if (y >= 0) { xsByRow[ y].add( x); }
                if (y <= 0) { xsByRow[-y].add(-x); }

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
            while (dy >= 0) {
                if (y >= 0) { xsByRow[ y].add( x); }
                if (y <= 0) { xsByRow[-y].add(-x); }

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
            while (-dy < dx) {
                if (y >= 0) { xsByRow[ y].add( x); }
                if (y <= 0) { xsByRow[-y].add(-x); }

                // Choose between (x+1, y) and (x+1, y-1).
                // Test (x+1, y-1); if inside, then go to (x+1, y), otherwise (x+1, y-1)
                x += 1;
                var sigma = A*x*x + 2*B*x*(y-1) + C*(y-1)*(y-1) - D;
                if (sigma >= 0) {
                    dx -= C;
                    dy += B;
                    y -= 1;
                }
                dx += B;
                dy -= A;
            }

            // Arc 5: down and maybe right until (xa, ya); y-- (x++)
            while (y > ya) {
                if (y >= 0) { xsByRow[ y].add( x); }
                if (y <= 0) { xsByRow[-y].add(-x); }

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

        // Now look at the traced coords a row at a time and figure out which portion to erase.

        // Of the three regions, inside and outside of the ellipse, which are in shadow and need
        // to be erased. This is left/right in terms of the un-rotated image.
        var eraseLeft = phase < 0.5;
        var eraseCenter = illuminationFraction < 0.5;
        var eraseRight = phase > 0.5;
        var upIsLeft = Math.sin(parallacticAngle) > 0;
        // System.println(Lang.format("angle: $1$; sin: $2$; cos: $3$", [parallacticAngle, Math.sin(parallacticAngle), Math.cos(parallacticAngle)]));
        var leftIsRight = Math.cos(parallacticAngle) < 0;

        // Reflect regions based on current rotation:
        var eraseScreenLeft = leftIsRight ? eraseRight : eraseLeft;
        var eraseScreenRight = leftIsRight ? eraseLeft : eraseRight;
        var eraseScreenUp = upIsLeft ? eraseLeft : eraseRight;
        var eraseScreenDown = upIsLeft ? eraseRight : eraseLeft;

        // Positive y-coord of the point on the major axis (aka ya, before selecting for quadrants):
        var y1 = (Math.cos(parallacticAngle)*majorAxis).abs().toNumber();

        // FIXME: note re-definition of x and y
        for (var y = 0; y <= radius; y += 1) {
            var xs = xsByRow[y];
            var count = xs.size();
            if (count == 0) {
                // This row is entirely outside the ellipse, so it's either all "left" or all "right".
                if ((upIsLeft and eraseLeft) or (!upIsLeft and eraseRight)) {
                    dc.setClip(0, radius - y, radius*2, 1);
                    dc.clear();
                }
                if ((upIsLeft and eraseRight) or (!upIsLeft and eraseLeft)) {
                    dc.setClip(0, radius + y, radius*2, 1);
                    dc.clear();
                }
            }
            else {
                var minX = xs[0];
                var maxX = xs[0];
                for (var i = 1; i < count; i += 1) {
                    var x = xs[i] as Number;
                    if (x < minX) { minX = x; }
                    if (x > maxX) { maxX = x; }
                }

                if (false) {
                    // For debug purposes, render the ellipse boundaries in each row.
                    // Note: the boundary pixels are considered to be outside of "center",
                    // so they get erased along with the left/right region.
                    dc.clearClip();
                    dc.setColor(leftIsRight ? Graphics.COLOR_GREEN : Graphics.COLOR_RED, -1);
                    dc.drawPoint(radius + minX, radius + y);
                    dc.drawPoint(radius - maxX, radius - y);
                    dc.setColor(leftIsRight ? Graphics.COLOR_RED : Graphics.COLOR_GREEN, -1);
                    dc.drawPoint(radius + maxX, radius + y);
                    dc.drawPoint(radius - minX, radius - y);
                }

                // First, the row with -y:
                {
                    var erase0;
                    if (y >= y1) { erase0 = eraseScreenUp; }
                    else         { erase0 = eraseScreenLeft; }
                    var erase1 = eraseCenter;
                    var erase2;
                    if (y >= y1) { erase2 = eraseScreenUp; }
                    else         { erase2 = eraseScreenRight; }

                    if (erase0 and !erase1 and erase2) {
                        // Erase on each side:
                        dc.setClip(radius + -radius, radius - y, -maxX - (-radius) + 1, 1);
                        dc.clear();
                        dc.setClip(radius + -minX, radius - y, radius - (-minX) + 1, 1);
                        dc.clear();
                    }
                    else if (erase0 or erase1 or erase2) {
                        // Erase one or two regions on the same side at once:

                        // First and last pixels to erase; both are included
                        var eraseL = -radius;
                        var eraseR = radius;

                        if (!erase0 and erase1)      { eraseL = -maxX+1; }
                        else if (!erase1 and erase2) { eraseL = -minX;   }

                        if (erase0 and !erase1)      { eraseR = -maxX;   }
                        else if (erase1 and !erase2) { eraseR = -minX-1; }

                        dc.setClip(radius + eraseL, radius - y, eraseR - eraseL + 1, 1);
                        dc.clear();
                    }
                }

                // Now, the row with +y:
                {
                    var erase0;
                    if (y >= y1) { erase0 = eraseScreenDown; }
                    else         { erase0 = eraseScreenLeft; }
                    var erase1 = eraseCenter;
                    var erase2;
                    if (y >= y1) { erase2 = eraseScreenDown; }
                    else         { erase2 = eraseScreenRight; }

                    if (erase0 and !erase1 and erase2) {
                        // Erase on each side:
                        dc.setClip(radius + -radius, radius + y, minX - (-radius) + 1, 1);
                        dc.clear();
                        dc.setClip(radius + maxX, radius + y, radius - maxX + 1, 1);
                        dc.clear();
                    }
                    else if (erase0 or erase1 or erase2) {
                        // Erase one or two regions on the same side at once:

                        // First and last pixels to erase; both are included
                        var eraseL = -radius;
                        var eraseR = radius;

                        if (!erase0 and erase1)      { eraseL = minX+1; }
                        else if (!erase1 and erase2) { eraseL = maxX;   }

                        if (erase0 and !erase1)      { eraseR = minX;   }
                        else if (erase1 and !erase2) { eraseR = maxX-1; }

                        dc.setClip(radius + eraseL, radius + y, eraseR - eraseL + 1, 1);
                        dc.clear();
                    }
                }
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
