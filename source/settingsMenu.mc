import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
// import Toybox.System;

enum MenuId {
    showSecondsId,
    showSPFId,
    locationOptionId,
    themeId
}

enum LocationOption {
    auto=0,
    hamden,
    newOrleans
}

enum ThemeOption {
    colorful=0,
    light,
    dark,
    lightAndDark
}

const LocationOptionLabels = [
        WatchUi.loadResource(Rez.Strings.LocationOptionAuto),
        WatchUi.loadResource(Rez.Strings.LocationOptionHamden),
        WatchUi.loadResource(Rez.Strings.LocationOptionNewOrleans),
    ] as Array<String>;

const ThemeLabels = [
        WatchUi.loadResource(Rez.Strings.ThemeColorful),
        WatchUi.loadResource(Rez.Strings.ThemeLight),
        WatchUi.loadResource(Rez.Strings.ThemeDark),
        WatchUi.loadResource(Rez.Strings.ThemeAuto),
    ] as Array<String>;


class SettingsMenu extends Menu2 {
    function initialize() {
        Menu2.initialize({:title=>"Customize"});

        var themeSelected = Properties.getValue("Theme") as ThemeOption;
        addItem(new MenuItem(WatchUi.loadResource(Rez.Strings.ThemeTitle) as String,
            ThemeLabels[themeSelected as Number], themeId, null));

        var showSecondsEnabled = Properties.getValue("ShowSeconds") as Boolean;
        addItem(new ToggleMenuItem(WatchUi.loadResource(Rez.Strings.ShowSecondsTitle) as String,
            {:enabled=>"show", :disabled=>"hide"}, showSecondsId, showSecondsEnabled, null));

        var showSPFEnabled = Properties.getValue("ShowSPF") as Boolean;
        addItem(new ToggleMenuItem(WatchUi.loadResource(Rez.Strings.ShowSPFTitle) as String,
            {:enabled=>"show", :disabled=>"hide"}, showSPFId, showSPFEnabled, null));

        var locationOptionSelected = Properties.getValue("LocationOption") as LocationOption;
        addItem(new MenuItem(WatchUi.loadResource(Rez.Strings.LocationOptionTitle) as String,
            LocationOptionLabels[locationOptionSelected as Number], locationOptionId, null));
    }
}

class SettingsMenuDelegate extends Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as MenuItem) {
        switch (item.getId() as MenuId) {
            case showSecondsId:
                var showSecondsEnabled = (item as ToggleMenuItem).isEnabled();
                Properties.setValue("ShowSeconds", showSecondsEnabled);
                break;
            case showSPFId:
                var showSPFEnabled = (item as ToggleMenuItem).isEnabled();
                Properties.setValue("ShowSPF", showSPFEnabled);
                break;
            case locationOptionId:
                var oldLoc = Properties.getValue("LocationOption") as Number;
                var newLoc = (oldLoc + 1) % 3;
                Properties.setValue("LocationOption", newLoc);
                item.setSubLabel(LocationOptionLabels[newLoc]);
                break;
            case themeId:
                var oldTheme = Properties.getValue("Theme") as Number;
                var newTheme = (oldTheme + 1) % 4;
                Properties.setValue("Theme", newTheme);
                item.setSubLabel(ThemeLabels[newTheme]);
                break;
            default:
                System.println(Lang.format("Unexpected menu item: $1$; $2$", [item.getId(), item.getLabel()]));
                break;
        }
    }
}