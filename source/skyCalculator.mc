import Toybox.Lang;
using Toybox.Math;
import Toybox.Test;
import Toybox.Time;

// Calculations to show objects in the sky on the watch face.
//
// Dead center is due south (azimuth = pi), with east near the left edge and west near
// the right edge.
// - altitude = 0 maps to the vertical center of the face
// - a "large", i.e. noon altitude is near the top of the face
//
// It's not yet clear what to do with negative altitudes and azimuths outside the
// E-S-W range. Either they can continue "off-screen" or could be mapped to a
// corresponding W-N-E range below the horizon.
//
// Note: this layout makes sense if the sun is in the southern sky, so that it rises
// on your left as you look to the south.
class SkyCalculator {
    // 1.0 would put the sun/moon, when directly overhead, at the exact top edge at the center
    // of the face. Chosen to make the track of the sun/moon fit in the upper semi-circle of the
    // dial most of the time, for most latitudes.
    private var MAX_HEIGHT as Float = 0.75;

    // 1.0 would put E/W at the exact edges of the screen.
    // 0.75 puts the "4th" (120°) tick mark just at the edge of the screen.
    // The idea here is to put that tick just *off* the screen, to reduce clutter.
    private var MAX_WIDTH as Float = 0.76;

    private var width as Number;
    private var height as Number;
    private var southFacing as Boolean;

    private var azimuth as Float = Math.PI;
    private var altitude as Float = 0.0;

    public function initialize(width as Number, height as Number, southFacing as Boolean) {
        self.width = width;
        self.height = height;
        self.southFacing = southFacing;
    }

    // azimuth: radians with 0 being due south
    // altitude: radians with 0 at the horizon
    public function setPosition(azimuth as Float, altitude as Float) as Void {
        self.azimuth = azimuth;
        self.altitude = altitude;
    }

    // Is the point onscreen, assuming a circular display?
    public function onscreen() as Boolean {
        var x = x() - width/2;
        var y = y() - height/2;
        var r = width/2;
        return x*x + y*y <= r*r;
    }

    public function x() as Number {
        var scale = MAX_WIDTH*(width/2);
        return width/2 + Math.round(scale*xFraction()).toNumber();
    }

    public function y() as Number {
        var scale = MAX_HEIGHT*(height/2);
        return height/2 - Math.round(scale*yFraction()).toNumber();
    }

    // Unitless value between -2 (when the point is furthest to the left) and 2 (when the point
    // is furthest to the right). Values of +/- 1.0 represent due east and due west, i.e. near the left
    // and right edges of the screen.
    private function xFraction() as Float {
        var center = southFacing ? 0 : Math.PI;
        var fraction = (azimuth - center)/(2*Math.PI);
        while (fraction <= -0.5) { fraction += 1.0; }
        while (fraction >= 0.5) { fraction -= 1.0; }
        return 4*fraction;
    }

    // Unitless value between -1 (when the point is directly below) and 1 (when the point is
    // directly overhead).
    private function yFraction() as Float {
        // "Flat" projection. Tends to produce a lower arc, unless the sun is really directly
        // overhead:
        return altitude/(Math.PI/2);

        // Project with sine. Tends to make a squarer arc, pushing the "corners" of the sun's
        // track further towards the edge of the display:
        // return Math.sin(altitude);
    }

    // If the point is offscreen, this is the x-coord of the nearest point at the left or right edge
    // of the display at the same y-coord (assuming a circular display.)
    public function pinnedX() as Number {
        var y = y() - height/2;
        var r = width/2;
        if (x() < width/2) {
            return width/2 - Math.round(Math.sqrt(r*r - y*y)).toNumber();
        }
        else {
            return width/2 + Math.round(Math.sqrt(r*r - y*y)).toNumber();
        }
    }
}


(:test)
function testSky(logger as Logger) as Boolean {
    var calc = new SkyCalculator(260, 260);

    calc.setPosition(0.0, 0.0);
    assertEqualLog(calc.x(), 130, logger);
    assertEqualLog(calc.y(), 130, logger);

    // Due east, fairly high in the sky:
    calc.setPosition(-Math.PI/2, Math.PI/3);
    assertEqualLog(calc.x(), 44, logger);
    assertEqualLog(calc.y(), 46, logger);

    // Due southwest, low in the sky:
    calc.setPosition(Math.PI/4, Math.PI/6);
    assertEqualLog(calc.x(), 173, logger);
    assertEqualLog(calc.y(), 81, logger);

    // TODO: what about values outside (-pi/2, pi/2)?

    return true;
}
