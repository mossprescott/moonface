import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;

// Calculations to arrange the 24 hours of the day around the dial, so that:
// - sunrise always appears at the precise left corner (270°)
// - sunset is at the right corner (90°)
//
// The hours of the days are spread evenly across the top half of the dial, and the
// hour of the night around the bottom half.
//
// Note: this layout makes sense if the sun is in the southern sky, so that it rises
// on your left as you look to the south.
class DialCalculator {
    // Time, in hours since midnight local time, of the sunrise today
    private var sunrise as Float = 6.0;

    // Time, in hours since midnight local time, of the sunrise today
    private var sunset as Float = 18.0;

    private var width as Number;
    private var height as Number;

    private var radius as Float = 0.9;

    // Pre-calculated values, hopefully used more than once.
    private var mIsDay as Boolean = true;
    private var tcos as Float = 1.0;
    private var tsin as Float = 0.0;

    public function initialize(width as Number, height as Number) {
        self.width = width;
        self.height = height;
    }

    public function setSunTimes(sunrise as Float, sunset as Float) as Void {
        self.sunrise = sunrise;
        self.sunset = sunset;

        // TODO: re-calculate stuff...
    }

    // A time we'd like to display on the dial in some way
    public function setValue(time as Float) as Void {
        // TEMP: linear interpolation between sunrise and sunset:
        var lengthOfDay = sunset - sunrise;
        var angle;
        if (time < sunrise) {
            mIsDay = false;

            var lengthOfNight = 24 - lengthOfDay;
            var morningFraction = (sunrise - time)/lengthOfNight;
            angle = Math.PI*(1 - morningFraction);
        }
        else if (time <= sunset) {
            mIsDay = true;
            var dayFraction = (time - sunrise)/lengthOfDay;
            angle = Math.PI*(1 + dayFraction);
        }
        else {
            mIsDay = false;

            var lengthOfNight = 24 - lengthOfDay;
            var eveningFraction = (time - sunset)/lengthOfNight;
            angle = Math.PI*eveningFraction;
        }

        tcos = Math.cos(angle).toFloat();
        tsin = Math.sin(angle).toFloat();
    }

    function isDay() as Boolean {
        return mIsDay;
    }

    // Radius as a fraction of the dimensions of the dial.
    public function setRadius(r as Float) as Void {
        var diameter = (width+height)/2;
        self.radius = r*diameter/2;
    }

    public function x() as Number {
        return Math.round(width/2 + radius*tcos).toNumber();
    }

    public function y() as Number {
        return Math.round(height/2 + radius*tsin).toNumber();
    }
}

// Convert UTC time (usually sometime today) to decimal hours since midnight, local time.
function localTimeOfDay(moment as Moment) as Float {
    var info = Gregorian.info(moment, Time.FORMAT_SHORT);
    return info.hour + info.min/60.0;
}

(:test)
function testNoon(logger as Logger) as Boolean {
    var calc = new DialCalculator(260, 260);
    calc.setRadius(1.0);

    // 2020-04-16 in Hamden, CT:
    var sunrise = 6 + 11/60.0;
    var sunset = 19 + 34/60.0;
    calc.setSunTimes(sunrise, sunset);

    calc.setValue(sunrise);
    assertEqualLog(calc.x(), 0, logger);
    assertEqualLog(calc.y(), 130, logger);

    calc.setValue(12.0);
    assertEqualLog(calc.x(), 103, logger);
    assertEqualLog(calc.y(), 3, logger);

    calc.setValue(sunset);
    assertEqualLog(calc.x(), 260, logger);
    assertEqualLog(calc.y(), 130, logger);

    return true;
}
