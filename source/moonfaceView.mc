import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class moonfaceView extends WatchUi.WatchFace {
    static var showSeconds as Boolean = false;

    static var COLOR_DAY_SKY as ColorType = 0x0055FF;
    static var COLOR_NIGHT_SKY as ColorType = 0x000000;
    static var COLOR_UNDERWORLD as ColorType = 0x555555;

    static var COLOR_DAY_FG as ColorType = 0x000000;
    static var COLOR_NIGHT_FG as ColorType = 0xFFFFFF;

    static var COLOR_SUN as ColorType = 0xFFFFAA;

    static var COLOR_NONE as ColorType = -1;

    static var TRACK_WIDTH as Number = 15;

    var moonPixels as MoonPixels;

    function initialize() {
        WatchFace.initialize();

        moonPixels = new MoonPixels();
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
        // Local time for display:
        var clockTime = System.getClockTime();

        // UTC time for astronomical calculations:
        var now = Time.now();

        // HACK:
        var hamden = new Position.Location({:latitude => 41.3460, :longitude => -72.9125, :format => :degrees});
        var loc = hamden;
        var elevation = 30.0;

        // TODO: redraw only seconds when appropriate? Or request one update per minute?

        var width = dc.getWidth();
        var height = dc.getHeight();
        // System.println(width);  // to DEBUG CONSOLE view in VS Code

        // TEMP: these are for Hamden on 4/16
        // var sunrise = 6 + 11/60.0;
        // var sunset = 19 + 34/60.0;
        // var sunrise = 4 + 11/60.0;
        // var sunset = 21 + 34/60.0;
        var sunTimes = Orbits.sunTimes(now, loc, elevation);
        var sunrise = localTimeOfDay(sunTimes.get(:rise));
        var sunset = localTimeOfDay(sunTimes.get(:set));

        // moon:
        // position: (azimuth: 0.6634013271521355, altitude: 0.5159978116213177, distance: 366582.4216626519, parallacticAngle: 0.49018236895626655)
        // illumination: (fraction: 0.14108114267560906, phase: 0.877434015284898, angle: 1.0984625984857552)
        // rise: 4/16/2023, 04:45; set: 4/16/2023, 15:48
        // at 18:14:
        // position: (azimuth: 1.7599871129151814, altitude: -0.44627517652070303, distance: 367151.127656053, parallacticAngle: 0.8440972773676563)
        // illumination: (fraction: 0.1220491397094714, phase: 0.8864006183816902, angle: 1.087339380493634)

        // var now = clockTime.hour + clockTime.min/60.0;

        // some bogus animation just to move it around for now:
        var moonPosition = Orbits.moonPosition(now, loc);
        // var moonAzimuth = 1.75 + (now - sunset)*Math.PI/12;
        // var moonAltitude = 0.5*Math.cos(moonAzimuth).toFloat();
        // var moonParallactic = moonAzimuth - 0.15;

        var localNow = localTimeOfDay(now);
        var isDay = localNow >= sunrise && localNow <= sunset;

        var faceColor = isDay ? COLOR_DAY_SKY : COLOR_NIGHT_SKY;

        // Relatively fixed; changes only at sunrise/set
        drawDialBackground(dc, faceColor);

        dc.setAntiAlias(true);

        // Draw indices, numerals, and the sun itself
        drawSunTrack(dc, sunrise, sunset, localNow);

        // Indicating direction reference for what view of the sky we're dealing with
        drawCompass(dc);

        drawMoon(dc, moonPosition.get(:azimuth), moonPosition.get(:altitude), moonPosition.get(:parallacticAngle), 0.11);

        var timeString = getLocalTimeString(clockTime);
        dc.setColor(Graphics.COLOR_WHITE, COLOR_NONE);
        var timeY = moonPosition.get(:altitude) >= 0 ? 40 : -30;  // FIXME: needs scaling for font size
        dc.drawText(width/2, height/2 + timeY, Graphics.FONT_NUMBER_MILD, timeString,
            Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);

        // TODO: add a single complication below the time? e.g. "Tue 18"

        // Note: draw *after* the view's layout is rendered
        // draw64ColorPalette(dc);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
        showSeconds = true;
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
        showSeconds = false;
    }

    function getLocalTimeString(clockTime as ClockTime) as String {
        var timeFormat = showSeconds ? "$1$:$2$:$3$" : "$1$:$2$";
        var hours = clockTime.hour;
        if (!System.getDeviceSettings().is24Hour && hours > 12) {
            hours = hours - 12;
        }
        return Lang.format(timeFormat, [hours, clockTime.min.format("%02d"), clockTime.sec.format("%02d")]);
    }

    function drawDialBackground(dc as Dc, faceColor as ColorType) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(faceColor, COLOR_UNDERWORLD);
        dc.clear();
        dc.fillRectangle(0, 0, width, height/2);

        // dc.setColor(faceColor, COLOR_UNDERWORLD);
        // dc.fillCircle(width/2, height/2, width/2 - TRACK_WIDTH);
    }


    // Note: all "times" are local, in hours. That is, noon has the value 12.0,
    // and midnight is 0.0 (or equivalently, 24.0).
    function drawSunTrack(dc as Dc, sunrise as Float, sunset as Float, current as Float) as Void {
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
                calc.setRadius(0.85);
                dc.drawText(calc.x(), calc.y(), Graphics.FONT_GLANCE, Lang.format("$1$", [h]),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }

            calc.setRadius(0.95);
            dc.fillCircle(calc.x(), calc.y(), 1.5);
        }

        calc.setValue(current);
        calc.setRadius(1.0);
        var r = width/15;  // puts the
        dc.setColor(COLOR_SUN, COLOR_NONE);
        dc.drawCircle(calc.x(), calc.y(), r);
       // if (calc.isDay()) {
        dc.setClip(0, 0, width, height/2);
            dc.fillCircle(calc.x(), calc.y(), r);
        dc.clearClip();
       // }
    }

    // TODO: deal with viewer looking to the north
    function drawCompass(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var deg45x = width/6;
        var deg30x = width/9;

        dc.setColor(Graphics.COLOR_LT_GRAY, COLOR_NONE);

        dc.fillRectangle(width/2 - 2*deg45x, height/2, 2, 3);
        dc.drawText(width/2 - 2*deg45x, height/2 + 10, Graphics.FONT_XTINY, "E",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.fillRectangle(width/2 - 2*deg30x, height/2, 2, 3);
        dc.fillRectangle(width/2 - deg30x, height/2, 2, 3);

        dc.fillRectangle(width/2, height/2, 2, 3);
        dc.drawText(width/2, height/2 + 10, Graphics.FONT_XTINY, "S",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.fillRectangle(width/2 + deg30x, height/2, 2, 3);
        dc.fillRectangle(width/2 + 2*deg30x, height/2, 2, 3);

        dc.fillRectangle(width/2 + 2*deg45x, height/2, 2, 3);
        dc.drawText(width/2 + 2*deg45x, height/2 + 10, Graphics.FONT_XTINY, "W",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // azimuth: radians with 0 at north
    // altitude: radians with 0 at the horizon
    // parallactic: radians with 0 being "normal"
    // illumination: ?
    function drawMoon(dc as Dc, azimuth as Float, altitude as Float, parallactic as Float, illumination as Float) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        var cx = width/2 + (width/3)*Math.sin(azimuth);
        var cy = height/2 - 25*altitude/0.5;

        // dc.setColor(Graphics.COLOR_LT_GRAY, COLOR_NONE);
        // dc.drawCircle(cx, cy, 20);

        // Maybe if I understood what the parallactic angle actually means I could explain, but this
        // does seem to put the moon right-side up, at least when it's up, and that even makes sense.
        moonPixels.draw(dc, cx.toNumber(), cy.toNumber(), 20, parallactic);
    }

    function draw64ColorPalette(dc as Dc) as Void {
        var s = 8;

        for (var z = 0; z < 4; z += 1) {
        for (var x = 0; x < 4; x += 1) {
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
}
