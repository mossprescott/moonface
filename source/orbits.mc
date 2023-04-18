import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.Test;

// Just to make it clear when a quantity is an angle, and in what units.
// Note: We need to use Doubles to represent time with precision, and those tiems often get
// scaled to produce angles which become the inputs to the trig functions, so it's simpler to
// just define all angles as either Double or Float.
// Angles coming back from inverse functions are always small, so Float would be plenty,
// but it's probably not worth worrying about at that point.
typedef Radians as Decimal;
typedef Degrees as Decimal;


// See https://github.com/mourner/suncalc/blob/master/suncalc.js
//
// Note: trying to be precise about types for the benefit of the reader, but Monkey C's type
// check seems to get a bit overwhelmed, so some of the types have to be hidden from it in
// comments.
class Orbits {
    // Local aliases for convenience:
    private static function sin(x as Radians) as Float { return Math.sin(x); }
    private static function cos(x as Radians) as Float { return Math.cos(x); }
    private static function tan(x as Radians) as Float { return Math.tan(x); }
    private static function asin(x as Float) as Radians { return Math.asin(x); }
    private static function acos(x as Float) as Radians { return Math.acos(x); }
    private static function atan(x as Float) as Radians { return Math.atan(x); }
    private static function atan2(x as Float, y as Float) as Radians { return Math.atan2(x, y); }

    // Radians per degree:
    // private static var rad as Radians = Math.PI/180;
    private static function toRadians(x as Degrees) as Radians { return x*Math.PI/180; }

    //
    // Date/time constants and conversions in weird astronomical units:
    //

    private static var daySecs as Number = 60*60*24;
    private static var julian1970 as Number = 2440588;
    private static var julian2000 as Number = 2451545;

    // Date-time as number of days since noon on the first day of the Julian period (4713BC).
    // See https://en.wikipedia.org/wiki/Julian_day.
    // Note: need more than Float's 24 bits of precision to represent contemporary dates
    // to the nearest the second; something like 46 bits is enough.
    typedef Julian as Double;

    private static function toJulian(date /* as Moment */) as Julian {
        return date.value().toDouble()/daySecs - 0.5 + julian1970;
    }

    private static function fromJulian(julian as Julian) as Moment {
        return new Moment(erase((julian + 0.5 - julian1970) * daySecs).toNumber());
    }

    // Date-time as number of days since noon on the first day of the year 2000?
    // Invented to simplify the calculation and/or improve their precision?
    typedef Days as Double;

    private static function toDays(date as Moment) as Days {
        return toJulian(date) - julian2000;
    }

    //
    // General calculations:
    //

    // Obliquity of the earth:
    private static var e as Radians = toRadians(23.4397);

    private static function rightAscension(l as Radians, b as Radians) as Radians {
        return atan2(sin(l)*cos(e) - tan(b)*sin(e), cos(l));
    }
    private static function declination(l as Radians, b as Radians) as Radians {
        return asin(sin(b)*cos(e) + cos(b)*sin(e)*sin(l));
    }

    private static function azimuth(h as Radians, phi as Radians, dec as Radians) as Radians {
        return atan2(sin(h), cos(h)*sin(phi) - tan(dec)*cos(phi));
    }
    private static function altitude(h as Radians, phi as Radians, dec as Radians) as Radians {
        return asin(sin(phi)*sin(dec) + cos(phi)*cos(dec)*cos(h));
    }

    private static function siderealTime(d as Days, lw as Radians) as Radians {
        return toRadians(280.16 + 360.9856235 * d) - lw;
    }

    // func astroRefraction(h : Double) -> Double {
    //     // the following formula works for positive altitudes only.
    //     // if h = -0.08901179 a div/0 would occur.
    //     let h = (h < 0) ? 0 : h

    //     // formula 16.4 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.
    //     // 1.02 / tan(h + 10.26 / (h + 5.10)) h in degrees, result in arc minutes -> converted to rad:
    //     return 0.0002967 / tan(h + 0.00312536 / (h + 0.08901179))
    // }


    //
    // Calculations for the sun:
    //

    private static function solarMeanAnomaly(d as Days) as Radians {
        return toRadians(357.5291 + 0.98560028 * d);
    }

    private static function eclipticLongitude(M as Radians) as Radians {
        // equation of center
        var C = toRadians(1.9148*sin(M) + 0.02*sin(2*M) + 0.0003*sin(3*M));
        // perihelion of the Earth
        var P = toRadians(102.9372);

        return M + C + P + Math.PI;
    }

    // { :dec, :ra }
    private static function sunCoords(d as Days) as Dictionary<Symbol, Radians> {
        var M = solarMeanAnomaly(d);
        var L = eclipticLongitude(M);

        return {
            :dec => declination(L, 0.0),
            :ra => rightAscension(L, 0.0),
        };
    }


    // Viewer-relative position of the sun at a moment in time.
    // :azimuth => north = 0.
    // :altitude => horizon = 0.
    public static function sunPosition(time as Moment, loc /*as Location*/) as Dictionary<Symbol, Radians> {
        var coords = loc.toRadians();
        var lw  = -coords[1];
        var phi = coords[0];
        var d   = toDays(time);

        var c  = erase(sunCoords(d));
        var H  = siderealTime(d, lw) - c.get(:ra);

        return {
            :azimuth => azimuth(H, phi, c.get(:dec)),
            :altitude => altitude(H, phi, c.get(:dec)),
        };
    }

    // HACK: defeat the type-checker, because it is sometimes confused when inferring the types of locals.
    static function erase(x) {
        return x;
    }

    private static var julian0 = 0.0009;

    // TODO: units? Days/revolutions, but on what basis?
    private static function julianCycle(d as Days, lw as Radians) as Number {
        return Math.round((d - julian0 - lw / (2 * Math.PI)));
    }

    private static function approxTransit(Ht as Radians, lw as Radians, n as Number) as Days {
        return julian0 + (Ht + lw) / (2 * Math.PI) + n;
    }
    private static function solarTransitJ(ds as Days, M as Radians, L as Radians) as Julian {
        return julian2000 + ds + 0.0053*sin(M) - 0.0069*sin(2*L);
    }

    private static function hourAngle(h as Radians, phi as Radians, d as Radians) as Radians {
        return acos((sin(h) - sin(phi)*sin(d)) / (cos(phi)*cos(d)));
    }
    private static function observerAngle(height as Float) as Degrees {
        return -2.076 * Math.sqrt(height) / 60;
    }

    // returns set time for the given sun altitude
    private static function getSetJ(h as Radians, lw as Radians, phi as Radians, dec as Radians, n as Number, M as Radians, L as Radians) as Julian {
        var w = hourAngle(h, phi, dec);
        var a = approxTransit(w, lw, n);
        return solarTransitJ(a, M, L);
    }

    // Times for the sun on the given day, at the viewer's position, including:
    // { :noon, :nadir, :rise, :set }
    //
    // `date` should be midnight local time, or really any time prior to sunrise.
    // `height` is in meters (or just use 0).
    //
    // Note: for our purposes, local time of day would be more useful, but this is at least
    // clearly defined and you can get there from here.
    public static function sunTimes(date as Moment, loc /*as Location*/, height as Float) as Dictionary<Symbol, Moment> {
        var coords = loc.toRadians();
        var lw  = -coords[1];
        var phi = coords[0];

        var dh = observerAngle(height);

        var d = toDays(date) + 0.5;  // HACK: if date is actually (local) midnight, as expected, we end up with yesterday's times.
        var n = julianCycle(d, lw);
        var ds = approxTransit(0.0, lw, n);

        var M = solarMeanAnomaly(ds);
        var L = eclipticLongitude(M);
        var dec = declination(L, 0.0);

        var Jnoon = solarTransitJ(ds, M, L);

        // // HACK:
        // System.println(formatTime(date));
        // System.println(formatTime(fromJulian(Jnoon)));
        // // seems to be off by one day

        // Angles (altitudes?) of the sun at various times of potential interest:
        var riseAngle = -0.8333;
        // var riseEndAngle = -0.3;
        // var dawnAngle = -6.0;
        // var nauticalDawnAngle = -12.0;
        // var nightEndAngle = -18;
        // var goldenHourEndAngle = 6;

        var Jset = getSetJ(toRadians(riseAngle + dh), lw, phi, dec, n, M, L);
        var Jrise = Jnoon - (Jset - Jnoon);

        return {
            :noon => fromJulian(Jnoon),
            :nadir => fromJulian(Jnoon-0.5),
            :rise => fromJulian(Jrise),
            :set => fromJulian(Jset),
        };
    }
}

(:test)
function testSunPosition(logger as Logger) as Boolean {

    // For reference, from my Swift port:
    // now: 2023-04-17 18:05:20 +0000; seconds: 1681754720.636094
    // sun: (azimuth: 0.5736154210007178, altitude: 0.9617565391201531)
    // solar noon:    4/17/2023, 12:52
    // sunrise:       4/17/2023, 06:09
    // sunset:        4/17/2023, 19:35
    // sunriseEnd:    4/17/2023, 06:12
    // sunsetStart:   4/17/2023, 19:32
    // dawn:          4/17/2023, 05:40
    // dusk:          4/17/2023, 20:04
    // nauticalDawn:  4/17/2023, 05:05
    // nauticalDusk:  4/17/2023, 20:38
    // nightEnd:      4/17/2023, 04:29
    // night:         4/17/2023, 21:15
    // goldenHourEnd: 4/17/2023, 06:46
    // goldenHour:    4/17/2023, 18:58
    // Moon:
    // position: (azimuth: 0.9277819437519993, altitude: 0.5089836452559305, distance: 369507.9094926991, parallacticAngle: 0.6464448130257752)
    // illumination: (fraction: 0.06630886962389404, phase: 0.9170995880185985, angle: 1.0574608202017584)
    // rise: 4/17/2023, 05:11; set: 4/17/2023, 17:03


    var april17 = new Moment(1681754720);
    var hamden = new Position.Location({:latitude => 41.3460, :longitude => -72.9125, :format => :degrees});

    var pos = Orbits.sunPosition(april17, hamden);
    assertApproximatelyEqual(pos.get(:azimuth), 0.5736, 0.01, logger);
    assertApproximatelyEqual(pos.get(:altitude), 0.9617, 0.01, logger);

    // Note: the actual error is something like 0.5%, which seems OK if not great.

    return true;
}

(:test)
function testSunTimes(logger as Logger) as Boolean {
    var hamden = new Position.Location({:latitude => 41.3460, :longitude => -72.9125, :format => :degrees});
    var midnight = Gregorian.moment({:year => 2023, :month => :april, :day => 17, :hour => 4, :minute => 0, :second => 0});

    var times = Orbits.sunTimes(midnight, hamden, 30.0);

    assertEqualLog(formatTime(times.get(:noon)),  "2023-04-17 12:52", logger);
    assertEqualLog(formatTime(times.get(:nadir)), "2023-04-17 00:52", logger);
    assertEqualLog(formatTime(times.get(:rise)),  "2023-04-17 06:09", logger);
    assertEqualLog(formatTime(times.get(:set)),   "2023-04-17 19:35", logger);

    return true;
}

// Note: the test assumes it's running in EST
(:test)
function testSunTimes2(logger as Logger) as Boolean {
    var guadalajara = new Position.Location({:latitude => 20.66, :longitude => -103.35, :format => :degrees});
    var midnight = Gregorian.moment({:year => 2023, :month => :august, :day => 15, :hour => 6, :minute => 0, :second => 0});

    // Note: actual elevation is 1543, but timeanddate.com seems to be ignoring that.
    var times = Orbits.sunTimes(midnight, guadalajara, 0.0); //1543.0);

    assertEqualLog(formatTime(times.get(:noon)),  "2023-08-15 14:59", logger);  // Actual: 14:57
    assertEqualLog(formatTime(times.get(:nadir)), "2023-08-15 02:59", logger);
    assertEqualLog(formatTime(times.get(:rise)),  "2023-08-15 08:33", logger);  // Actual: 08:32
    assertEqualLog(formatTime(times.get(:set)),   "2023-08-15 21:24", logger);  // Actual: 21:22

    return true;
}

// HH:MM for tests
(:debug)
function formatTime(time as Moment) as String {
    var today = Gregorian.info(time, Time.FORMAT_SHORT);
    return Lang.format(
        "$1$-$2$-$3$ $4$:$5$",
        [
            today.year,
            today.month.format("%02d"),
            today.day.format("%02d"),
            today.hour.format("%02d"),
            today.min.format("%02d"),
        ]
    );
}