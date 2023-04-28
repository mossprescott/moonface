import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

const COLOR_DAY_SKY as ColorType = 0x0055AA;
const COLOR_NIGHT_SKY as ColorType = 0x000000;
const COLOR_UNDERWORLD as ColorType = 0x550055;

const COLOR_DAY_FG as ColorType = 0x000000;
const COLOR_NIGHT_FG as ColorType = 0xFFFFFF;

const COLOR_SUN as ColorType = 0xFFFFAA;

const COLOR_NONE as ColorType = -1;

const TRACK_WIDTH as Number = 15;

const MOON_RADIUS = 20;


class moonfaceView extends WatchUi.WatchFace {
    static var showSeconds as Boolean = false;

    var moonBuffer as MoonBuffer;

    // Cache some state between draw calls:
    var isMoonUp as Boolean = true;
    var isSunUp as Boolean = true;

    function initialize() {
        WatchFace.initialize();

        moonBuffer = new MoonBuffer(MOON_RADIUS);
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        showSeconds = Properties.getValue("ShowSeconds");
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        System.println("onUpdate()");
        var start = System.getTimer();        drawAll(dc, false);
        var end = System.getTimer();

        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(dc.getWidth()/2, dc.getHeight()-10, Graphics.FONT_XTINY,
            Lang.format("$1$ms", [end - start]),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {    }

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
        System.println("onPartialUpdate()");
        if (showSeconds) {
            drawAll(dc, true);
        }
    }



    private function drawAll(dc as Dc, secondsOnly as Boolean) as Void {
        // Local time for display:
        var clockTime = System.getClockTime();

        if (!secondsOnly) {
            // UTC time for astronomical calculations:
            var now = Time.now();

            // HACK:
            var hamden = new Position.Location({:latitude => 41.3460, :longitude => -72.9125, :format => :degrees});
            var loc = hamden;
            var elevation = 30.0;

            // TODO: redraw only seconds when appropriate? Or request one update per minute?

            var sunTimes = Orbits.sunTimes(now, loc, elevation);
            var sunrise = localTimeOfDay(sunTimes.get(:rise));
            var sunset = localTimeOfDay(sunTimes.get(:set));

            var sunPosition = Orbits.sunPosition(now, loc);
            var moonPosition = Orbits.moonPosition(now, loc);
            var moonIllumination = Orbits.moonIllumination(now);
            // System.println(moonIllumination);

            var localNow = localTimeOfDay(now);
            isSunUp = localNow >= sunrise && localNow <= sunset;
            isMoonUp = moonPosition.get(:altitude) >= 0;

            var indexColor = isSunUp ? Graphics.COLOR_BLACK : Graphics.COLOR_LT_GRAY;

            var faceColor = isSunUp ? COLOR_DAY_SKY : COLOR_NIGHT_SKY;

            // Relatively fixed; changes only at sunrise/set
            drawDialBackground(dc, faceColor);

            dc.setAntiAlias(true);

            // Draw indices, numerals, and the sun itself
            drawSunTrack(dc, sunrise, sunset, localNow);
            // Indicating direction reference for what view of the sky we're dealing with
            drawCompass(dc);

            drawSunTrackOffDial(dc, loc, Time.today(), indexColor);

            drawSun(dc, sunPosition.get(:azimuth), sunPosition.get(:altitude));

            dc.setAntiAlias(false);
            drawMoon(dc, moonPosition.get(:azimuth), moonPosition.get(:altitude),
                    moonPosition.get(:parallacticAngle),
                    moonIllumination.get(:fraction), moonIllumination.get(:phase));
            dc.setAntiAlias(true);
        }

        // TODO: always draw the sun, because it can sometimes overlap the time when the moon is down during the day.

        drawTime(dc, clockTime);

        // TODO: add a single complication below the time? e.g. "Tue 18"

        // Note: draw *after* the view's layout is rendered
        // draw64ColorPalette(dc);
    }

    private function drawDialBackground(dc as Dc, faceColor as ColorType) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(faceColor, COLOR_UNDERWORLD);
        dc.clear();
        dc.fillRectangle(0, 0, width, height/2);

        // dc.setColor(faceColor, COLOR_UNDERWORLD);
        // dc.fillCircle(width/2, height/2, width/2 - TRACK_WIDTH);
    }

    // Draw the current time, either above or below the horizon depending on whether the moon is up.
    // This is called independently of all other drawing when only the seconds need updating, so it
    // draws both foreground and background to erase the previous display.
    private function drawTime(dc as Dc, clockTime as ClockTime) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        var timeString = getLocalTimeString(clockTime);

        var timeY;
        var bgColor;
        if (isMoonUp) {
            timeY = 50;  // FIXME: needs scaling for font size
            bgColor = COLOR_UNDERWORLD;
        }
        else {
            timeY = -30;  // FIXME: needs scaling for font size
            bgColor = isSunUp ? COLOR_DAY_SKY : COLOR_NIGHT_SKY;
        }
        dc.setColor(Graphics.COLOR_WHITE, bgColor);
        dc.drawText(width/2, height/2 + timeY, Graphics.FONT_NUMBER_MILD, timeString,
            Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Note: all "times" are local, in hours. That is, noon has the value 12.0,
    // and midnight is 0.0 (or equivalently, 24.0).
    private function drawSunTrack(dc as Dc, sunrise as Float, sunset as Float, current as Float) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var calc = new DialCalculator(width, height);
        calc.setSunTimes(sunrise, sunset);

        calc.setValue(current);
        var isDay = calc.isDay();

        for (var h = 0; h < 24; h += 1) {
            calc.setValue(h as Float);
            dc.setColor(isDay ? Graphics.COLOR_BLACK : Graphics.COLOR_LT_GRAY, COLOR_NONE);

            if (h % 2 == 0) {
                calc.setRadius(0.90);
                if (calc.y() <= height/2 + 10) {
                    dc.drawText(calc.x(), calc.y(), Graphics.FONT_GLANCE, formatHourString(h),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                }
            }

            // TEMP:
            // calc.setRadius(0.95);
            // dc.fillCircle(calc.x(), calc.y(), 1.5);
        }

        // TEMP: don't draw the sun at the edge of the dial for now. Maybe replace it with some
        // other indicator later?
    //     calc.setValue(current);
    //     calc.setRadius(1.0);
    //     var r = width/15;  // puts the
    //     dc.setColor(COLOR_SUN, COLOR_NONE);
    //     dc.drawCircle(calc.x(), calc.y(), r);
    //    // if (calc.isDay()) {
    //     dc.setClip(0, 0, width, height/2);
    //         dc.fillCircle(calc.x(), calc.y(), r);
    //     dc.clearClip();
       // }
    }

    // Draw an index at the location of the sun at each hour of the day.
    private function drawSunTrackOffDial(dc as Dc, loc as Position.Location, midnight as Moment, indexColor as ColorType) as Void {
        var skyCalc = new SkyCalculator(dc.getWidth(), dc.getHeight());

        dc.setColor(indexColor, COLOR_NONE);

        for (var h = 0; h < 24; h += 1) {
            var t = midnight.add(new Duration(h*60*60));
            var pos = Orbits.sunPosition(t, loc);
            skyCalc.setPosition(pos.get(:azimuth), pos.get(:altitude));
            var r = h % 2 == 0 ? 2.0 : 1.0;
            dc.fillCircle(skyCalc.x(), skyCalc.y(), r);
        }
    }

    // TODO: deal with viewer looking to the north
    private function drawCompass(dc as Dc) as Void {
        var EAST = -Math.PI/2;
        var SOUTH = 0.0;
        var WEST = Math.PI/2;

        var skyCalc = new SkyCalculator(dc.getWidth(), dc.getHeight());

        dc.setColor(Graphics.COLOR_LT_GRAY, COLOR_NONE);

        skyCalc.setPosition(EAST, 0.0);
        dc.fillRectangle(skyCalc.x()-1, skyCalc.y(), 2, 3);
        dc.drawText(skyCalc.x(), skyCalc.y() + 10, Graphics.FONT_XTINY, "E",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        skyCalc.setPosition((2*EAST + SOUTH)/3, 0.0);
        dc.fillRectangle(skyCalc.x()-1, skyCalc.y(), 2, 3);
        skyCalc.setPosition((EAST + 2*SOUTH)/3, 0.0);
        dc.fillRectangle(skyCalc.x()-1, skyCalc.y(), 2, 3);

        skyCalc.setPosition(SOUTH, 0.0);
        dc.fillRectangle(skyCalc.x()-1, skyCalc.y(), 2, 3);
        dc.drawText(skyCalc.x(), skyCalc.y() + 10, Graphics.FONT_XTINY, "S",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        skyCalc.setPosition((2*SOUTH + WEST)/3, 0.0);
        dc.fillRectangle(skyCalc.x()-1, skyCalc.y(), 2, 3);
        skyCalc.setPosition((SOUTH + 2*WEST)/3, 0.0);
        dc.fillRectangle(skyCalc.x()-1, skyCalc.y(), 2, 3);

        skyCalc.setPosition(WEST, 0.0);
        dc.fillRectangle(skyCalc.x()-1, skyCalc.y(), 2, 3);
        dc.drawText(skyCalc.x(), skyCalc.y() + 10, Graphics.FONT_XTINY, "W",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Draw the sun in the sky in the same projection as the moon. This probably makes more sense as an
    // alternative to drawing it rotating around the dial, but for now it helps to make the moon's
    // appearance understandable.
    // azimuth: radians with 0 at north
    // altitude: radians with 0 at the horizon
    private function drawSun(dc as Dc, azimuth as Float, altitude as Float) as Void {
        var skyCalc = new SkyCalculator(dc.getWidth(), dc.getHeight());
        skyCalc.setPosition(azimuth, altitude);

        dc.setColor(COLOR_SUN, COLOR_NONE);
        dc.fillCircle(skyCalc.x(), skyCalc.y(), 5);
    }

    // azimuth: radians with 0 at north
    // altitude: radians with 0 at the horizon
    // parallactic: radians with 0 being "normal"
    // illumination: radians with ? being ?
    private function drawMoon(dc as Dc, azimuth as Float, altitude as Float, parallactic as Float, illuminationFraction as Float, phase as Float) as Void {
        var skyCalc = new SkyCalculator(dc.getWidth(), dc.getHeight());
        skyCalc.setPosition(azimuth, altitude);

        // dc.setColor(Graphics.COLOR_LT_GRAY, COLOR_NONE);
        // dc.drawCircle(cx, cy, 20);

        moonBuffer.draw(dc, skyCalc.x(), skyCalc.y(), parallactic, illuminationFraction, phase);
    }

    private function draw64ColorPalette(dc as Dc) as Void {
        var s = 8;

        for (var z = 0; z < 4; z += 1) {        for (var x = 0; x < 4; x += 1) {
        for (var y = 0; y < 4; y += 1) {
            var color = ((z * 85) << 16)  // red: a whole square for each level
                      + ((x * 85) << 8)   // green: a column for each level
                       + (y * 85);        // blue: a row for each level
            // color = Graphics.COLOR_LT_GRAY;
            dc.setColor(color, Graphics.COLOR_BLACK);
            var x0 = 130 - 2*s*5 + z*s*5;
            var y0 = 150;
            dc.fillRectangle(x0 + x*s, y0 + y*s, s, s);
        }
        }
        }
    }


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

class MoonBuffer {
    // How long in seconds to keep re-using previously-rendered pixels before starting fresh
    const RENDER_INTERVAL = new Duration(5*60);

    var radius as Number;
    var pixelData as MoonPixels;

    // Strong reference, keeps the buffer in memory once it's created.
    var bitmap as BufferedBitmap?;

    // When present, the same pixels will be saved and re-used until we pass this time.
    var validUntil as Moment?;
    // In the simulator (and maybe when the time is adjusted?) the time can jump backward
    var validFrom as Moment?;

    function initialize(radius as Number) {
        self.radius = radius;
        pixelData = new MoonPixels();
    }

    function draw(dc as Dc, x as Number, y as Number, angle as Decimal, fraction as Decimal, phase as Decimal) as Void {
        if (bitmap == null) {
            //Test.assert(Graphics has :createBufferedBitmap);
            var ref = Graphics.createBufferedBitmap({
                :width => radius*2, :height => radius*2,
                // TODO: save memory and possibly time by using a limited palette?
                //:palette => [0x555555, 0xAAAAA, 0xFFFFFF, 0x0] as Array<ColorType>
            });
            bitmap = ref.get();
        }

        var now = Time.now();
        if (validUntil == null or now.greaterThan(validUntil) or (validFrom != null and now.lessThan(validFrom))) {
            System.println("Rendering...");

            var bufferDc = bitmap.getDc();
            bufferDc.clear();
            pixelData.draw(bufferDc, radius, radius, radius, angle, fraction, phase);

            validFrom = now;
            validUntil = now.add(RENDER_INTERVAL);
        }
        else {
            System.println("Using previous rendering");
        }

        dc.drawBitmap(x - radius, y - radius, bitmap);
    }
}
