import Toybox.Lang;

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

        tcos = Math.cos(angle);
        tsin = Math.sin(angle);
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
        return Math.round(width/2 + radius*tcos);
    }

    public function y() as Number {
        return Math.round(height/2 + radius*tsin);
    }
}