import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
// import Toybox.System;

enum MenuId {
    showSeconds,
    showSPF,
    locationOption
}

enum LocationOption {
    auto=0,
    hamden,
    newOrleans
}

const LocationOptionLabels = [
        WatchUi.loadResource(Rez.Strings.LocationOptionAuto),
        WatchUi.loadResource(Rez.Strings.LocationOptionHamden),
        WatchUi.loadResource(Rez.Strings.LocationOptionNewOrleans),
    ] as Array<String>;


class SettingsMenu extends Menu2 {
    function initialize() {
        Menu2.initialize({:title=>"Customize"});

        var showSecondsEnabled = Properties.getValue("ShowSeconds") as Boolean;
        addItem(new ToggleMenuItem(WatchUi.loadResource(Rez.Strings.ShowSecondsTitle) as String,
            {:enabled=>"show", :disabled=>"hide"}, showSeconds, showSecondsEnabled, null));

        var showSPFEnabled = Properties.getValue("ShowSPF") as Boolean;
        addItem(new ToggleMenuItem(WatchUi.loadResource(Rez.Strings.ShowSPFTitle) as String,
            {:enabled=>"show", :disabled=>"hide"}, showSPF, showSPFEnabled, null));

        var locationOptionSelected = Properties.getValue("LocationOption") as LocationOption;
        addItem(new MenuItem(WatchUi.loadResource(Rez.Strings.LocationOptionTitle) as String,
            LocationOptionLabels[locationOptionSelected as Number], locationOption, null));
    }
}

class SettingsMenuDelegate extends Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as MenuItem) {
        switch (item.getId() as MenuId) {
            case showSeconds:
                var showSecondsEnabled = (item as ToggleMenuItem).isEnabled();
                Properties.setValue("ShowSeconds", showSecondsEnabled);
                break;
            case showSPF:
                var showSPFEnabled = (item as ToggleMenuItem).isEnabled();
                Properties.setValue("ShowSPF", showSPFEnabled);
                break;
            case locationOption:
                var locationOptionSelected = Properties.getValue("LocationOption") as Number;
                var newValue = (locationOptionSelected + 1) % 3;
                Properties.setValue("LocationOption", newValue);
                item.setSubLabel(LocationOptionLabels[newValue]);
            default:
                System.println(Lang.format("Unexpected menu item: $1$; $2$", [item.getId(), item.getLabel()]));
                break;
        }
    }
}