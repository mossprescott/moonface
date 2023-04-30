import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

enum MenuId {
    showSeconds
}

class SettingsMenu extends Menu2 {
    function initialize() {
        Menu2.initialize({:title=>"Customize"});

        var checked = Properties.getValue("ShowSeconds") as Boolean;
        addItem(new ToggleMenuItem("Seconds", {:enabled=>"show", :disabled=>"hide"}, showSeconds, checked, {}));
    }
}

class SettingsMenuDelegate extends Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as MenuItem) {
        switch (item.getId() as MenuId) {
            case showSeconds:
                var checked = (item as ToggleMenuItem).isEnabled();
                Properties.setValue("ShowSeconds", checked);
                break;
            default:
                System.println(Lang.format("Unexpected menu item: $1$; $2$", [item.getId(), item.getLabel()]));
                break;
        }
    }
}