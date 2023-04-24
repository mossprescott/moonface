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
    // of the face.
    private var MAX_HEIGHT as Float = 0.75;

    private var width as Number;
    private var height as Number;

    private var azimuth as Float = Math.PI;
    private var altitude as Float = 0.0;

    public function initialize(width as Number, height as Number) {
        self.width = width;
        self.height = height;
    }

    // azimuth: radians with 0 at north/south(?!)
    // altitude: radians with 0 at the horizon
    public function setPosition(azimuth as Float, altitude as Float) as Void {
        self.azimuth = azimuth;
        self.altitude = altitude;
        // System.println(Lang.format("$1$, $2$", [azimuth, altitude]));
    }

    public function x() as Number {
        return width/2 + Math.round((width/3)*azimuth/(Math.PI/2)).toNumber();
    }

    public function y() as Number {
        // var fraction = altitude/(Math.PI/2);
        var fraction = Math.sin(altitude);
        return height/2 - Math.round((height/2)*MAX_HEIGHT*fraction).toNumber();
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
    assertEqualLog(calc.y(), 73, logger);

    // Due southwest, low in the sky:
    calc.setPosition(Math.PI/4, Math.PI/6);
    assertEqualLog(calc.x(), 173, logger);
    assertEqualLog(calc.y(), 101, logger);

    // TODO: what about values outside (-pi/2, pi/2)?

    return true;
}
