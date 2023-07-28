import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class moonfaceApp extends Application.AppBase {
    public static var throttle as Throttle = new Throttle();

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as Array<Views or InputDelegates>? {
        return [ new moonfaceView() ] as Array<Views or InputDelegates>;
    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    function getSettingsView() {
        return [new SettingsMenu(), new SettingsMenuDelegate()] as Array<Menu2 or Menu2InputDelegate>;
    }
}

function getApp() as moonfaceApp {
    return Application.getApp() as moonfaceApp;
}