import Toybox.Graphics;
import Toybox.Lang;

module MFColors {
    // Set of colors to be used together on the screen at a particular moment.
    class Palette {
        // Backgrounds:
        var sky as ColorType;
        var below as ColorType;

        // Foregrounds:
        var index as ColorType;
        var compass as ColorType;
        var time as ColorType;  // also, complication, coords, and spf

        // Other:
        var sun as ColorType;
        var moonIndicator as ColorType;

        function initialize(colors as Array<ColorType>) {
            sky = colors[0];
            below = colors[1];
            index = colors[2];
            compass = colors[3];
            time = colors[4];
            sun = colors[5];
            moonIndicator = colors[6];
        }
    }

    // A collection of palettes that are used to render at different times of day.
    class Theme {
        var day as Palette;
        var night as Palette;

        function initialize(day as Palette, night as Palette?) {
            self.day = day;
            if (night != null) {
                self.night = night;
            }
            else {
                self.night = day;
            }
        }
    }

    const Colorful as Theme = new Theme(
        new Palette([
            /* sky     */ 0x0055AA,
            /* below   */ 0x550055,
            /* index   */ Graphics.COLOR_BLACK,
            /* compass */ Graphics.COLOR_LT_GRAY,
            /* time    */ Graphics.COLOR_WHITE,
            /* sun     */ 0xFFFFAA,
            /* moonInd */ Graphics.COLOR_LT_GRAY,
            ] as Array<ColorType>),
        new Palette([
            /* sky     */ Graphics.COLOR_BLACK,
            /* below   */ 0x550055,
            /* index   */ Graphics.COLOR_LT_GRAY,
            /* compass */ Graphics.COLOR_LT_GRAY,
            /* time    */ Graphics.COLOR_WHITE,
            /* sun     */ 0xFFFFAA,
            /* moonInd */ Graphics.COLOR_LT_GRAY,
            ] as Array<ColorType>)
        );
}