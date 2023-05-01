import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

enum MenuId {
    showSeconds,
    showSPF
}

class SettingsMenu extends Menu2 {
    function initialize() {
        Menu2.initialize({:title=>"Customize"});

        var showSecondsEnabled = Properties.getValue("ShowSeconds") as Boolean;
        addItem(new ToggleMenuItem("Seconds", {:enabled=>"show", :disabled=>"hide"}, showSeconds, showSecondsEnabled, {}));

        var showSPFEnabled = Properties.getValue("ShowSPF") as Boolean;
        addItem(new ToggleMenuItem("Draw Time", {:enabled=>"show", :disabled=>"hide"}, showSPF, showSPFEnabled, {}));
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
            default:
                System.println(Lang.format("Unexpected menu item: $1$; $2$", [item.getId(), item.getLabel()]));
                break;
        }
    }
}