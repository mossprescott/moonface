import Toybox.Application;
using Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;
using MFColors;

const COLOR_NONE as ColorType = -1;

const TRACK_WIDTH as Number = 15;


const Hamden as Location3 = new Location3(Orbits.toRadians(41.3460), Orbits.toRadians(-72.9125), 30.0);
const NewOrleans as Location3 = new Location3(Orbits.toRadians(29.97), Orbits.toRadians(-90.3), 1.0);
const Santiago as Location3 = new Location3(Orbits.toRadians(-33.47), Orbits.toRadians(-70.79), 570.0);
const Pacoa as Location3 = new Location3(Orbits.toRadians(0.0456), Orbits.toRadians(-71.25), 100.0);
const Kangiqsujuaq  as Location3 = new Location3(Orbits.toRadians(61.601), Orbits.toRadians(-72.06), 10.0);


class moonfaceView extends WatchUi.WatchFace {
    static var showSeconds as Boolean = false;

    // var moonBuffer as MoonBuffer;
    var moonPixels as MoonPixels;

    var theme as MFColors.Theme;

    // Cache some state between draw calls:
    var isSunUp as Boolean = true;
    var palette as MFColors.Palette;
    var frameCount as Number = 0;

    var lastSunTrack as SunTrack?;

    function initialize() {
        WatchFace.initialize();

        // moonBuffer = new MoonBuffer(MOON_UP_RADIUS);
        moonPixels = new MoonPixels();

        theme = MFColors.LightAndDark;
        palette = theme.day;
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        moonfaceApp.throttle.updateStarted();

        // System.println("onUpdate()");

        readProperties();
        var loc = readLocation();

        drawAll(dc, loc, false);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

    // The user has just looked at their watch.
    function onExitSleep() as Void {
        System.println("low power mode: off");
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
        System.println("low power mode: on");
        showSeconds = false;
    }

    // Update only the seconds, and only if enabled in settings.
    // Note: it's not clear to me whether this applies only to OLED watches, but it seems
    // prudent to do as little drawing as possible.
    function onPartialUpdate(dc as Dc) as Void {
        moonfaceApp.throttle.updateStarted();

        System.println("onPartialUpdate()");
        if (showSeconds) {
            var loc = readLocation();
            drawAll(dc, loc, true);
        }
    }

    private function readProperties() as Void {
        showSeconds = Properties.getValue("ShowSeconds") as Boolean;
        switch (Properties.getValue("Theme") as ThemeOption) {
            case colorful:
                theme = MFColors.Colorful;
                break;
            case light:
                theme = MFColors.Light;
                break;
            case dark:
                theme = MFColors.Dark;
                break;
            case lightAndDark:
                theme = MFColors.LightAndDark;
                break;
        }
    }

    private function readLocation() as Location3 {
        switch (Properties.getValue("LocationOption") as LocationOption) {
            case hamden:
                return Hamden;
            case newOrleans:
                return NewOrleans;
            case santiago:
                return Santiago;
            case pacoa:
                return Pacoa;
            case kangiqsujuaq:
                return Kangiqsujuaq;
            default:
                var location = Locations.getLocation();
                if (location == null) {
                    return Hamden;
                }
                else {
                    if (location.altitude == null) {
                        location.altitude = 0.0;
                    }
                    return location;
                }
        }
    }

    private function drawAll(dc as Dc, location as Location3, secondsOnly as Boolean) as Void {
        var frameStart = System.getTimer();
        frameCount += 1;

        // Local time for display:
        var clockTime = System.getClockTime();

        // UTC time for astronomical calculations:
        var now = Time.now();

        var sunTrack = getSunTrack(location, Time.today());

        // Note: this doesn't really work for equatorial latitudes, especially when the moon is
        // fairly full. In that case, the moon can be in the north while the sun is in the south,
        // and vice versa, even when both are in the sky (e.g. sun is WSW while the moon is ENE).
        // Then, after sunset, the sun is below the horizon, the moon is up, but it doesn't appear
        // on the watchface.
        var facingSouth = sunTrack.isInSouthernSky();

        if (!secondsOnly) {
            // TODO: redraw only seconds when appropriate? Or request one update per minute?

            var sunTimes = Orbits.sunTimes(now, location);
            var sunrise = localTimeOfDay(sunTimes.get(:rise) as Moment);
            var sunset = localTimeOfDay(sunTimes.get(:set) as Moment);

            var sunPosition = Orbits.sunPosition(now, location);

            var localNow = localTimeOfDay(now);
            isSunUp = localNow >= sunrise && localNow <= sunset;
            palette = isSunUp ? theme.day : theme.night;

            // Relatively fixed; changes only at sunrise/set
            drawDialBackground(dc);

            // Draw indices, numerals, and the sun itself
            // drawSunTrack(dc, sunrise, sunset, localNow);

            drawSunTrackOffDial(dc, sunTrack, facingSouth);

            dc.setAntiAlias(true);
            drawSun(dc, sunPosition.get(:azim) as Float, sunPosition.get(:alt) as Float,
                facingSouth);
            dc.setAntiAlias(false);
        }

        // FIXME: at extreme latitudes, this can overlap the sun track as well, so ideally would
        // be drawn earlier, but that means more work on "seconds only" updates.
        drawTime(dc, clockTime);

        // Indicating direction reference for what view of the sky we're dealing with.
        // Drawn after the time, which can overlap it slightly
        drawCompass(dc, facingSouth);

        var MOON_DEBUG = true;
        if (MOON_DEBUG) {
            var framesPerRotation = 100;
            var framesPerCycle = 421;  // roughly a multiple but not quite to hit more combinations
            var angle = 2*Math.PI*frameCount/framesPerRotation;
            var fraction = (Math.cos(2*Math.PI*frameCount/framesPerCycle) + 1)/2;
            var phase = (frameCount % framesPerCycle) / framesPerCycle.toFloat();
            moonPixels.draw(dc, dc.getWidth()/2, dc.getHeight()/3, moonPixels.getNativeRadius(),
                    angle, fraction, phase);
        }
        else {
            // The moon can overlap the time when it's low in the sky and close to full.
            var moonPosition = Orbits.moonPosition(now, location);
            // TODO: don't recalculate the illumination every time
            var moonIllumination = Orbits.moonIllumination(now);
            // System.println(moonIllumination);
            drawMoon(dc, moonPosition[:azim] as Float, moonPosition[:alt] as Float,
                    moonPosition[:parallacticAngle] as Float,
                    moonIllumination[:fraction] as Float, moonIllumination[:phase] as Float,
                    facingSouth);
        }

        dc.setColor(palette.time, -1);

        // One complication under the time
        // TODO: make it a setting
        var complication = Complications.getComplication(new Complications.Id(Complications.COMPLICATION_TYPE_WEEKDAY_MONTHDAY));
        if (complication != null) {
            dc.drawText(dc.getWidth()/2, dc.getHeight()-55, Graphics.FONT_TINY,
                Lang.format("$1$", [complication.value]),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Coords:
        dc.drawText(dc.getWidth()/2, dc.getHeight()-30, Graphics.FONT_XTINY,
            location.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var frameEnd = System.getTimer();

        if (Properties.getValue("ShowSPF") as Boolean) {
            drawSPF(dc, frameStart, frameEnd);
        }
    }

    private function drawSPF(dc as Dc, start as Number, end as Number) as Void {
        dc.setColor(palette.time, -1);
        dc.drawText(dc.getWidth()/2, dc.getHeight()-10, Graphics.FONT_XTINY,
            Lang.format("$1$ms", [end - start]),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // A tiny indicator so you can tell how often drawing is happening:
        if (frameCount & 1 == 0) {
            dc.drawRectangle(dc.getWidth()/2-1, dc.getHeight()-2, 2, 2);
        }
    }



    private function drawDialBackground(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(palette.sky, -1);
        dc.fillRectangle(0, 0, width, height/2);
        dc.setColor(palette.below, -1);
        dc.fillRectangle(0, height/2, width, height/2);
    }

    // Draw the current time, either above or below the horizon depending on whether the moon is up.
    // This is called independently of all other drawing when only the seconds need updating, so it
    // draws both foreground and background to erase the previous display.
    private function drawTime(dc as Dc, clockTime as ClockTime) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        var timeString = getLocalTimeString(clockTime);

        var timeY = 37;  // FIXME: needs scaling for font size
        dc.setColor(palette.time, palette.below);
        dc.drawText(width/2, height/2 + timeY, Graphics.FONT_NUMBER_MEDIUM, timeString,
            Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // // Note: all "times" are local, in hours. That is, noon has the value 12.0,
    // // and midnight is 0.0 (or equivalently, 24.0).
    // private function drawSunTrack(dc as Dc, sunrise as Float, sunset as Float, current as Float) as Void {
    //     var width = dc.getWidth();
    //     var height = dc.getHeight();
    //     var calc = new DialCalculator(width, height);
    //     calc.setSunTimes(sunrise, sunset);

    //     for (var h = 0; h < 24; h += 1) {
    //         calc.setValue(h as Float);
    //         dc.setColor(palette.index, COLOR_NONE);

    //         if (h % 2 == 0) {
    //             calc.setRadius(0.90);
    //             if (calc.y() <= height/2 + 10) {
    //                 dc.drawText(calc.x(), calc.y(), Graphics.FONT_GLANCE, formatHourString(h),
    //                     Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    //             }
    //         }

    //         // TEMP:
    //         // calc.setRadius(0.95);
    //         // dc.fillCircle(calc.x(), calc.y(), 1.5);
    //     }

    //     // TEMP: don't draw the sun at the edge of the dial for now. Maybe replace it with some
    //     // other indicator later?
    // //     calc.setValue(current);
    // //     calc.setRadius(1.0);
    // //     var r = width/15;  // puts the
    // //     dc.setColor(COLOR_SUN, COLOR_NONE);
    // //     dc.drawCircle(calc.x(), calc.y(), r);
    // //    // if (calc.isDay()) {
    // //     dc.setClip(0, 0, width, height/2);
    // //         dc.fillCircle(calc.x(), calc.y(), r);
    // //     dc.clearClip();
    //    // }
    // }

    // Check for a saved SunTrack that's still accurate, otherwise construct an up-to-date track
    // and cache it for next time.
    private function getSunTrack(location as Location3, midnight as Moment) as SunTrack {
        var saved = lastSunTrack;
        if (saved != null
            and midnight.compare(saved.midnight) == 0
            and location.greatCircleDistance(saved.loc) <= 5000.0)
        {
            return saved;
        }
        else {
            System.println("Calculating sun track");
            var newTrack = new SunTrack(location, midnight);
            lastSunTrack = newTrack;
            return newTrack;
        }
    }

    // Draw an index at the location of the sun at each hour of the day.
    // Note: small circles render very slowly if anti-aliased, and very ugly if not. Squares look
    // decent and render fast. Some kind of middle ground is probably possible.
    private function drawSunTrackOffDial(dc as Dc, track as SunTrack, facingSouth as Boolean) as Void {
        var skyCalc = new SkyCalculator(dc.getWidth(), dc.getHeight(), facingSouth);

        dc.setColor(palette.index, COLOR_NONE);

        for (var h = 0; h < 24; h += 1) {
            skyCalc.setPosition(track.getAzimuth(h), track.getAltitude(h));
            if (skyCalc.onscreen()) {
                if (h%6 == 0) {
                    // 6, 12, and 18
                    // Quick and dirty rect with corners knocked out:
                    dc.fillRectangle(skyCalc.x()-4, skyCalc.y()-3, 4*2-1, 3*2-1);
                    dc.fillRectangle(skyCalc.x()-3, skyCalc.y()-4, 3*2-1, 4*2-1);
                }
                else {
                    var r = h%3 == 0 ? 3 : 2;
                    dc.fillRectangle(skyCalc.x()-r, skyCalc.y()-r, r*2-1, r*2-1);
                }
            }
        }
    }

    private function drawCompass(dc as Dc, facingSouth as Boolean) as Void {
        var skyCalc = new SkyCalculator(dc.getWidth(), dc.getHeight(), facingSouth);

        var horizon = palette.horizon;
        if (horizon != null) {
            dc.setColor(horizon, COLOR_NONE);
            var y = dc.getHeight()/2 - 1;
            dc.drawLine(0, y, dc.getWidth(), y);
        }

        dc.setColor(palette.compass, COLOR_NONE);

        var labels = ["S", null, null, "W", null, null, "N", null, null, "E", null, null] as Array<String?>;

        for (var i = 0; i < 12; i += 1) {
            skyCalc.setPosition(i*Math.PI/6, 0.0);
            // FIXME: supress the ticks that lie outside E/W. They tend to overlap the sun track
            // indices and look busy. Or maybe just adjust the scaling to make them end up off screen.
            if (skyCalc.onscreen()) {
                dc.fillRectangle(skyCalc.x()-1, skyCalc.y(), 2, 3);
                var str = labels[i];
                if (str != null) {
                    dc.drawText(skyCalc.x(), skyCalc.y() + 10, Graphics.FONT_XTINY, str,
                                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                }
            }
        }
    }

    // Draw the sun in the sky in the same projection as the moon. This probably makes more sense as an
    // alternative to drawing it rotating around the dial, but for now it helps to make the moon's
    // appearance understandable.
    // azimuth: radians with 0 at north
    // altitude: radians with 0 at the horizon
    private function drawSun(dc as Dc, azimuth as Float, altitude as Float, facingSouth as Boolean) as Void {
        var skyCalc = new SkyCalculator(dc.getWidth(), dc.getHeight(), facingSouth);
        skyCalc.setPosition(azimuth, altitude);

        dc.setColor(palette.sun, COLOR_NONE);
        if (skyCalc.onscreen()) {
            if (altitude >= 0) {
                dc.fillCircle(skyCalc.x(), skyCalc.y(), 5);
            }
            else {
                dc.drawCircle(skyCalc.x(), skyCalc.y(), 5);
            }
        }
        else {
            drawOffscreenIndicator(dc, skyCalc, 6);
        }
    }

    // azimuth: radians with 0 at north
    // altitude: radians with 0 at the horizon
    // parallactic: radians with 0 being "normal"
    // illumination: radians with ? being ?
    private function drawMoon(dc as Dc,
            azimuth as Float, altitude as Float, parallactic as Float,
            illuminationFraction as Float, phase as Float,
            facingSouth as Boolean) as Void {
        var skyCalc = new SkyCalculator(dc.getWidth(), dc.getHeight(), facingSouth);
        skyCalc.setPosition(azimuth, altitude);

        if (skyCalc.onscreen()) {
            var radius;
            if (altitude >= 0) {
                radius = moonPixels.getNativeRadius();
            }
            else {
                radius = moonPixels.getNativeRadius()/2;
            }
            moonPixels.draw(dc, skyCalc.x(), skyCalc.y(), radius, parallactic, illuminationFraction, phase);
        }
        else {
            dc.setColor(palette.moonIndicator, COLOR_NONE);
            drawOffscreenIndicator(dc, skyCalc, 6);
        }
    }

    private function drawOffscreenIndicator(dc as Dc, calc as SkyCalculator, size as Number) as Void {
        var x = calc.pinnedX();
        var y = calc.y();
        if (x < dc.getWidth()/2) {
            dc.fillPolygon([[x+size, y-size], [x+size, y+size], [x, y]] as Array<Array<Numeric>>);
        }
        else {
            dc.fillPolygon([[x-size, y-size], [x, y], [x-size, y+size]] as Array<Array<Numeric>>);
        }
    }

    // private function draw64ColorPalette(dc as Dc) as Void {
    //     var s = 8;

    //     for (var z = 0; z < 4; z += 1) {
    //     for (var x = 0; x < 4; x += 1) {
    //     for (var y = 0; y < 4; y += 1) {
    //         var color = ((z * 85) << 16)  // red: a whole square for each level
    //                   + ((x * 85) << 8)   // green: a column for each level
    //                    + (y * 85);        // blue: a row for each level
    //         // color = Graphics.COLOR_LT_GRAY;
    //         dc.setColor(color, Graphics.COLOR_BLACK);
    //         var x0 = 130 - 2*s*5 + z*s*5;
    //         var y0 = 150;
    //         dc.fillRectangle(x0 + x*s, y0 + y*s, s, s);
    //     }
    //     }
    //     }
    // }


    private function getLocalTimeString(clockTime as ClockTime) as String {
        var timeFormat = showSeconds ? "$1$:$2$:$3$" : "$1$:$2$";
        var hours = formatHourString(clockTime.hour);
        return Lang.format(timeFormat, [hours, clockTime.min.format("%02d"), clockTime.sec.format("%02d")]);
    }

    private function formatHourString(hours as Number) as String {
        if (!System.getDeviceSettings().is24Hour) {
            hours = ((hours + 11) % 12) + 1;
        }
        return hours.toString();
    }
}

// Position of the sun relative to an observer's location at each hour of the day.
// These values only need to be recomputed once per day, unless the location changes significantly.
class SunTrack {
    var loc as Location3;
    var midnight as Moment;

    var track as Array<Array<Float>>;

    function initialize(loc as Location3, midnight as Moment) {
        self.loc = loc;
        self.midnight = midnight;

        self.track = [] as Array<Array<Float>>;

        for (var h = 0; h < 24; h += 1) {
            var t = midnight.add(new Duration(h*60*60));
            var pos = Orbits.sunPosition(t, loc);
            track.add([pos.get(:azim), pos.get(:alt)] as Array<Float>);
        }
    }

    // Angle in radians from north, for hours between 0 and 23.
    function getAzimuth(hour as Number) as Float {
        return track[hour][0];
    }

    // Angle in radians above the horizon, for hours between 0 and 23.
    function getAltitude(hour as Number) as Float {
        return track[hour][1];
    }

    function isInSouthernSky() as Boolean {
        var noonAzimuth = getAzimuth(12);
        return Math.cos(noonAzimuth) > 0;
    }
}

// class MoonBuffer {
//     // How long in seconds to keep re-using previously-rendered pixels before starting fresh
//     const RENDER_INTERVAL = new Duration(5*60);

//     var maxRadius as Number;
//     var pixelData as MoonPixels;

//     // Strong reference, keeps the buffer in memory once it's created.
//     var savedBitmap as BufferedBitmap?;

//     // Radius of previous drawing in the buffer.
//     var savedRadius as Number?;

//     // If previous drawing was incomplete, the row to continue with.
//     var drawCont as Number?;

//     // When present, the same pixels will be saved and re-used until we pass this time.
//     var validUntil as Moment?;
//     // In the simulator (and maybe when the time is adjusted?) the time can jump backward
//     var validFrom as Moment?;

//     var dbOptions;

//     function initialize(maxRadius as Number) {
//         self.maxRadius = maxRadius;
//         pixelData = new MoonPixels();

//         var rotate90 = new AffineTransform();
//         // rotate90.m00 = 0.0;
//         // rotate90.m01 = -1.0;
//         // rotate90.m10 = 1.0;
//         // rotate90.m11 = 0.0;
//         rotate90.setMatrix([
//             0.0, -1.0, 0.0,
//             1.0, 0.0, 0.0,
//         ] as Array<Float>);
//         dbOptions = {
//             // :transform => rotate90,
//         };
//     }

//     function draw(dc as Dc, x as Number, y as Number, radius as Number, angle as Decimal, fraction as Decimal, phase as Decimal) as Void {
//         var bitmap;
//         if (savedBitmap != null) {
//             bitmap = savedBitmap;
//         }
//         else {
//             //Test.assert(Graphics has :createBufferedBitmap);
//             var ref = Graphics.createBufferedBitmap({
//                 :width => maxRadius*2, :height => maxRadius*2,
//                 // TODO: save memory and possibly time by using a limited palette?
//                 // :palette => [0xFF000000, 0xFF555555, 0xFFAAAAAA, 0xFFFFFFFF, 0x00000000] as Array<ColorType>
//                 // :palette => [0x000000, 0xFFFFFF] as Array<ColorType>
//             });
//             bitmap = ref.get() as BufferedBitmap;
//             savedBitmap = bitmap;
//         }

//         var ALWAYS_DRAW = true;
//         var needReset = ALWAYS_DRAW;

//         if (radius != savedRadius) {
//             needReset = true;
//         }

//         var now = Time.now();
//         if (validUntil == null or now.greaterThan(validUntil) or (validFrom != null and now.lessThan(validFrom))) {
//             needReset = true;
//         }

//         // if (needReset) {
//         //     System.println("Rendering...");

//         //     var bufferDc = bitmap.getDc();
//         //     bufferDc.clear();
//         //     drawCont = pixelData.draw(bufferDc, radius, radius, radius, angle, fraction, phase, null);

//         //     savedRadius = radius;
//         //     validFrom = now;
//         //     validUntil = now.add(RENDER_INTERVAL);
//         // }
//         // else if (drawCont != null) {
//         //     System.println(Lang.format("Continue rendering from row $1$...", [drawCont]));
//         //     var bufferDc = bitmap.getDc();
//         //     drawCont = pixelData.draw(bufferDc, radius, radius, radius, angle, fraction, phase, drawCont);
//         // }
//         // else {
//         //     System.println("Using previous rendering");
//         // }

//         // // dc.drawBitmap(x - radius, y - radius, bitmap);
//         // dc.drawBitmap2(x-radius, y-radius, bitmap, dbOptions);

//         var img = WatchUi.loadResource(Rez.Drawables.Moon30_15);
//         dc.drawBitmap2(x-30, y-30, img, dbOptions);
//     }
// }
