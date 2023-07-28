import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.Test;

// Just to make it clear when a quantity is an angle, and in what units.
// Note: We need to use Doubles to represent time with precision, and those times often get
// scaled to produce angles which become the inputs to the trig functions, so it's simpler to
// just define all angles as either Double or Float.
// Angles coming back from inverse functions are always small, so Float is plenty, and
// we force such values into the Float type (aliased as FRadians) just in case it saves some
// time/space when they're used later.
typedef Radians as Decimal;
typedef Degrees as Decimal;
typedef FRadians as Float;
typedef DRadians as Double;

// See https://github.com/mourner/suncalc/blob/master/suncalc.js
//
// Note: trying to be precise about types for the benefit of the reader, but Monkey C's type
// check seems to get a bit overwhelmed, so some of the types have to be hidden from it in
// comments.
class Orbits {
    // Local aliases for convenience:
    private static function sin(x as Radians) as Decimal { return Math.sin(x); }
    private static function cos(x as Radians) as Decimal { return Math.cos(x); }
    private static function tan(x as Radians) as Decimal { return Math.tan(x); }
    private static function asin(x as Decimal) as Radians { return Math.asin(x); }
    private static function acos(x as Decimal) as Radians { return Math.acos(x); }
    private static function atan(x as Decimal) as Radians { return Math.atan(x); }
    private static function atan2(x as Decimal, y as Decimal) as Radians { return Math.atan2(x, y); }

    // Radians per degree:
    // private static var rad as Radians = Math.PI/180;
    /*private*/ static function toRadians(x as Degrees) as Radians { return x*Math.PI/180; }

    //
    // Date/time constants and conversions in weird astronomical units:
    //

    private static const daySecs as Number = 60*60*24;
    private static var julian1970 as Number = 2440588;
    private static var julian2000 as Number = 2451545;

    // Date-time as number of days since noon on the first day of the Julian period (4713BC).
    // See https://en.wikipedia.org/wiki/Julian_day.
    // Note: need more than Float's 24 bits of precision to represent contemporary dates
    // to the nearest the second; something like 46 bits is enough.
    typedef Julian as Double;

    private static function toJulian(date as Moment) as Julian {
        return date.value().toDouble()/daySecs - 0.5 + julian1970;
    }

    private static function fromJulian(julian as Julian) as Moment {
        return new Moment(((julian + 0.5 - julian1970) * daySecs).toNumber());
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

    private static function rightAscension(l as Radians, b as Radians) as FRadians {
        return atan2(sin(l)*cos(e) - tan(b)*sin(e), cos(l)).toFloat();
    }
    private static function declination(l as Radians, b as Radians) as FRadians {
        return asin(sin(b)*cos(e) + cos(b)*sin(e)*sin(l)).toFloat();
    }

    private static function azimuth(h as Radians, phi as Radians, dec as Radians) as FRadians {
        return atan2(sin(h), cos(h)*sin(phi) - tan(dec)*cos(phi)).toFloat();
    }
    private static function altitude(h as Radians, phi as Radians, dec as Radians) as FRadians {
        return asin(sin(phi)*sin(dec) + cos(phi)*cos(dec)*cos(h)).toFloat();
    }

    private static function siderealTime(d as Days, lw as Radians) as Radians {
        return toRadians(280.16 + 360.9856235 * d) - lw;
    }

    private static function astroRefraction(h as Radians) as FRadians {
        // the following formula works for positive altitudes only.
        // if h = -0.08901179 a div/0 would occur.
        if (h < 0) { h = 0; }

        // formula 16.4 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.
        // 1.02 / tan(h + 10.26 / (h + 5.10)) h in degrees, result in arc minutes -> converted to rad:
        return 0.0002967 / tan(h + 0.00312536 / (h + 0.08901179)).toFloat();
    }


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

    private static function sunCoords(d as Days)
            as { :dec as Float, :ra as Float } {
        var M = solarMeanAnomaly(d);
        var L = eclipticLongitude(M);

        return {
            :dec => declination(L, 0.0),
            :ra => rightAscension(L, 0.0),
        };
    }


    // Viewer-relative position of the sun at a moment in time.
    // :azimuth => south = 0.
    // :altitude => horizon = 0.
    public static function sunPosition(time as Moment, loc as Location3)
            as { :azimuth as Float, :altitude as Float } {
        var lw  = -loc.longitude as Float;
        var phi = loc.latitude;
        var d   = toDays(time);

        var c  = sunCoords(d);
        var H  = siderealTime(d, lw) - (c[:ra] as Float);

        return {
            :azimuth => azimuth(H, phi, c[:dec] as Float),
            :altitude => altitude(H, phi, c[:dec] as Float),
        };
    }

    private static var julian0 as DRadians = (0.0009).toDouble();

    // TODO: units? Days/revolutions, but on what basis?
    private static function julianCycle(d as Days, lw as Radians) as Number {
        return Math.round((d - julian0 - lw / (2 * Math.PI))).toNumber();
    }

    private static function approxTransit(Ht as Radians, lw as Radians, n as Number) as Days {
        return julian0 + (Ht + lw) / (2 * Math.PI) + n;
    }
    private static function solarTransitJ(ds as Days, M as Radians, L as Radians) as Julian {
        return julian2000 + ds + 0.0053*sin(M) - 0.0069*sin(2*L);
    }

    private static function hourAngle(h as Radians, phi as Radians, d as Radians) as FRadians {
        return acos((sin(h) - sin(phi)*sin(d)) / (cos(phi)*cos(d))).toFloat();
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
    //
    // TODO: produce null if the sun never rises (e.g. in the Arctic Circle in winter).
    public static function sunTimes(date as Moment, loc as Location3)
            as { :noon as Moment, :nadir as Moment, :rise as Moment, :set as Moment } {
        var lw  = -loc.longitude;
        var phi = loc.latitude;
        var height = loc.altitude;
        if (height == null) { height = 0.0; }

        var dh = observerAngle(height);

        var d = toDays(date) + 0.5;  // HACK: if date is actually (local) midnight, as expected, we end up with yesterday's times.
        var n = julianCycle(d, lw);
        var ds = approxTransit(0.0, lw, n);

        var M = solarMeanAnomaly(ds);
        var L = eclipticLongitude(M);
        var dec = declination(L, 0.0);

        var Jnoon = solarTransitJ(ds, M, L);

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

    //
    // Moon calculations:
    //

    // :ra, :dec in Radians
    // :dist in km
    private static function moonCoords(d as Days)
            as { :ra as Float, :dec as Float, :dist as Float } {
        var L = toRadians(218.316 + 13.176396 * d); // ecliptic longitude
        var M = toRadians(134.963 + 13.064993 * d); // mean anomaly
        var F = toRadians(93.272 + 13.229350 * d);  // mean distance

        var l  = L + toRadians(6.289) * sin(M); // longitude
        var b  = toRadians(5.128) * sin(F);     // latitude
        var dt = (385001 - 20905 * cos(M)).toFloat();  // distance to the moon in km

        return {
            :ra => rightAscension(l, b),
            :dec => declination(l, b),
            :dist => dt,
        };
    }

    // Position of the moon in the sky, given the viewer's location.
    // { :azimuth, :altitude, :distance (km), :parallacticAngle }
    public static function moonPosition(date as Moment, loc as Location3)
            as { :azimuth as Float, :altitude as Float, :distance as Float, :parallacticAngle as Float } {
        var lw  = -loc.longitude;
        var phi = loc.latitude;
        var d   = toDays(date);

        var c = moonCoords(d);
        var H = siderealTime(d, lw) - (c[:ra] as Float);
        var h = altitude(H, phi, c[:dec] as Float);
        // formula 14.1 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.
        var pa = atan2(sin(H), tan(phi)*cos(c[:dec] as Float) - sin(c[:dec] as Float)*cos(H)) as FRadians;

        var correctedH = h + astroRefraction(h); // altitude correction for refraction

        return {
            :azimuth => azimuth(H, phi, c[:dec] as Float),
            :altitude => correctedH,
            :distance => c[:dist] as Float,
            :parallacticAngle => pa,
        };
    }


    // calculations for illumination parameters of the moon,
    // based on http://idlastro.gsfc.nasa.gov/ftp/pro/astro/mphase.pro formulas and
    // Chapter 48 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.
    // Note: these parameters are independent of viewing location. We all see the same moon!
    public static function moonIllumination(date as Moment)
            as { :fraction as Float, :phase as Float, :angle as Float } {
        var d = toDays(date);
        var s = sunCoords(d);
        var m = moonCoords(d);

        var sdist = 149598000.0; // distance from Earth to Sun in km

        var sdec = s[:dec] as Float;
        var sra = s[:ra] as Float;
        var mdec = m[:dec] as Float;
        var mra = m[:ra] as Float;
        var mdist = m[:dist] as Float;

        var phi = acos(sin(sdec)*sin(mdec) + cos(sdec)*cos(mdec)*cos(sra - mra));
        var inc = atan2(sdist * sin(phi),
                        mdist - sdist*cos(phi));
        var angle = atan2(cos(sdec)*sin(sra - mra),
                          sin(sdec)*cos(mdec) - cos(sdec)*sin(mdec)*cos(sra - mra));

        return {
            :fraction => floatOrFail((1 + cos(inc)) / 2),
            :phase => floatOrFail(0.5 + 0.5*inc*(angle < 0 ? -1 : 1)/Math.PI),
            :angle => floatOrFail(angle),
        };
    }

    // Use this function when a value really definitely should always be a Float, or there's
    // a programming error. Could be replaced by no-op for deployment.
    private static function floatOrFail(x as Decimal) as Float {
        switch (x) {
            case instanceof Float:
                return x as Float;
            case instanceof Double:
                System.error(Lang.format("Float value required; found double: $1$", [x]));
            default:
                // Presumably only null could slip in here, unless the type checker is truly confused.
                System.error(Lang.format("Float value required; found: $1$", [x]));
        }
    }

    // public enum RiseAndSet {
    //     case alwaysUp
    //     case alwaysDown
    //     case times(Date, Date)
    // }

    // /// calculations for moon rise/set times are based on http://www.stargazing.net/kepler/moonrise.html article
    // public static func getTimes(_ date: Date, lat: Double, lng: Double, inUTC: Bool) -> RiseAndSet {
    //     var calendar = Calendar.current
    //     if (inUTC) {
    //         calendar.timeZone = TimeZone.gmt
    //     }
    //     let t = Calendar.current.startOfDay(for: date)

    //     let hc = 0.133 * rad
    //     var h0 = getPosition(t, lat: lat, lng: lng).altitude - hc

    //     var rise: Double? = nil
    //     var set: Double? = nil
    //     var ye = 0.0
    //    // go in 2-hour chunks, each time seeing if a 3-point quadratic curve crosses zero (which means rise or set)
    //     for hi in 0...11 {
    //         let i = 2*hi + 1  // odd hours from 01 to 23
    //         let h1 = getPosition(t.later(byHours: Double(i)), lat: lat, lng: lng).altitude - hc
    //         let h2 = getPosition(t.later(byHours: Double(i + 1)), lat: lat, lng: lng).altitude - hc

    //         let a = (h0 + h2) / 2 - h1
    //         let b = (h2 - h0) / 2
    //         let xe = -b / (2 * a)
    //         ye = (a * xe + b) * xe + h1
    //         let d = b * b - 4 * a * h1

    //         var roots = 0
    //         var x1: Double = 0
    //         var x2: Double = 0
    //         if (d >= 0) {
    //             let dx = sqrt(d) / (abs(a) * 2)
    //             x1 = xe - dx
    //             x2 = xe + dx
    //             if abs(x1) <= 1 { roots += 1 }
    //             if abs(x2) <= 1 { roots += 1 }
    //             if x1 < -1 { x1 = x2 }
    //         }

    //         if roots == 1 {
    //             if (h0 < 0) { rise = Double(i) + x1 }
    //             else { set = Double(i) + x1 }

    //         } else if roots == 2 {
    //             rise = Double(i) + (ye < 0 ? x2 : x1);
    //             set = Double(i) + (ye < 0 ? x1 : x2);
    //         }

    //         if (rise != nil) && (set != nil) {
    //             break
    //         }

    //         h0 = h2
    //     }

    //     switch (rise, set) {
    //     case (nil, nil):
    //         if ye > 0 {
    //             return .alwaysUp
    //         }
    //         else {
    //             return .alwaysDown
    //         }
    //     default:
    //         return .times(t.later(byHours: rise ?? 0), t.later(byHours: set ?? 0))
    //     }
    // }

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

    var pos = Orbits.sunPosition(april17, Hamden);
    assertApproximatelyEqual(pos.get(:azimuth), 0.5736, 0.01, logger);
    assertApproximatelyEqual(pos.get(:altitude), 0.9617, 0.01, logger);

    // Note: the actual error is something like 0.5%, which seems OK if not great.

    return true;
}

(:test)
function testSunTimes(logger as Logger) as Boolean {
    var midnight = Gregorian.moment({:year => 2023, :month => :april, :day => 17, :hour => 4, :minute => 0, :second => 0});

    var times = Orbits.sunTimes(midnight, Hamden);

    assertEqualLog(formatTime(times.get(:noon)),  "2023-04-17 12:52", logger);
    assertEqualLog(formatTime(times.get(:nadir)), "2023-04-17 00:52", logger);
    assertEqualLog(formatTime(times.get(:rise)),  "2023-04-17 06:09", logger);
    assertEqualLog(formatTime(times.get(:set)),   "2023-04-17 19:35", logger);

    return true;
}

// Note: the test assumes it's running in EST
(:test)
function testSunTimes2(logger as Logger) as Boolean {
    // Note: actual elevation is 1543m, but timeanddate.com seems to be ignoring that.
    var guadalajara = new Location3(Orbits.toRadians(20.66), Orbits.toRadians(-103.35), 0.0);
    var midnight = Gregorian.moment({:year => 2023, :month => :august, :day => 15, :hour => 6, :minute => 0, :second => 0});

    var times = Orbits.sunTimes(midnight, guadalajara);

    assertEqualLog(formatTime(times.get(:noon)),  "2023-08-15 14:59", logger);  // Actual: 14:57
    assertEqualLog(formatTime(times.get(:nadir)), "2023-08-15 02:59", logger);
    assertEqualLog(formatTime(times.get(:rise)),  "2023-08-15 08:33", logger);  // Actual: 08:32
    assertEqualLog(formatTime(times.get(:set)),   "2023-08-15 21:24", logger);  // Actual: 21:22

    return true;
}

(:test)
function testMoonPosition(logger as Logger) as Boolean {
    var april17 = new Moment(1681754720);

    var pos = Orbits.moonPosition(april17, Hamden);
    assertApproximatelyEqual(pos.get(:azimuth),          0.9277, 0.01, logger);
    assertApproximatelyEqual(pos.get(:altitude),         0.5089, 0.01, logger);
    assertApproximatelyEqual(pos.get(:distance),      369507.90,  1.0, logger);
    assertApproximatelyEqual(pos.get(:parallacticAngle), 0.6464, 0.01, logger);

    return true;
}

(:test)
function testMoonIllumination(logger as Logger) as Boolean {
    var april17 = new Moment(1681754720);

    var pos = Orbits.moonIllumination(april17);
    assertApproximatelyEqual(pos.get(:fraction), 0.06630, 0.0001, logger);
    assertApproximatelyEqual(pos.get(:phase),    0.9171,  0.0001, logger);
    assertApproximatelyEqual(pos.get(:angle),    1.057,   0.001, logger);

    return true;
}

// HH:MM for tests (local time)
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