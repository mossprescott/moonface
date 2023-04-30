using Toybox.Activity;
import Toybox.Application;
import Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.Weather;

const LOCATION_KEY = "location";
const LATITUDE_FIELD = "latitude";
const LONGITUDE_FIELD = "longitude";
const ALTITUDE_FIELD = "altitude";

typedef StoredLocation as Dictionary<String, Float>;

// Location with elevation (latitude and longitude in degrees, altitude in meters, if available).
class Location3 {
    public var latitude as Float;
    public var longitude as Float;
    public var altitude as Float or Null;

    function initialize(latitude as Float, longitude as Float, altitude as Float) {
        self.latitude = latitude;
        self.longitude = longitude;
        self.altitude = altitude;
    }

    function toString() {
        return Lang.format("$1$°$2$ $3$°$4$ $5$m", [
            (latitude.abs()*180/Math.PI).format("%0.1f"),
            latitude < 0 ? "S" : "N",
            (longitude.abs()*180/Math.PI).format("%0.1f"),
            longitude < 0 ? "W" : "E",
            altitude != null ? altitude.format("%0.0f") : "?",
        ]);
    }



    // Get the best available location, by checking two sources of "current" (recent) location,
    // or else loading a saved location from storage. If no location has ever been available, then
    // null.
    public static function getLocation() as Location3? {
        var loc = latestLocation();
        if (loc != null) {
            writeStoredLocation(loc);
            return loc;
        }

        loc = readStoredLocation();
        return loc;
    }

    private static function writeStoredLocation(loc /*as Location3*/) as Void {
        Storage.setValue(LOCATION_KEY, {
            LATITUDE_FIELD => loc.latitude,
            LONGITUDE_FIELD => loc.longitude,
            ALTITUDE_FIELD => loc.altitude
        });
    }

    private static function readStoredLocation() as Location3 or Null {
        var stored = erase(Storage.getValue(LOCATION_KEY));
        if (stored != null) {
            // TODO: parse from the dictionary, handling unexpected values in some consistent way
            System.println(Lang.format("Location from storage: $1$", [stored]));
            if (stored.hasKey(LATITUDE_FIELD) and stored.hasKey(LONGITUDE_FIELD) and stored.hasKey(ALTITUDE_FIELD)) {
                return new Location3(
                    stored.get(LATITUDE_FIELD) as Float,
                    stored.get(LONGITUDE_FIELD) as Float,
                    stored.get(ALTITUDE_FIELD) as Float);  // or Null?
            }
        }
        return null;
    }

    // Erase a type that confuses the type checker.
    private static function erase(x) { return x; }

    // See https://forums.garmin.com/developer/connect-iq/f/discussion/305484/how-best-to-get-a-gps-location-in-a-watch-face
    private static function latestLocation() as Location3 or Null {
        // First try looking for a recently completed activity. This will give an accurate location
        // when available, but it's only present for a short time.
        var loc = null;
        var altitude = null;

        var activity = erase(Activity.getActivityInfo());
        if (activity != null and activity.currentLocation != null) {
            loc = activity.currentLocation;
            altitude = activity.altitude;
            System.println("Found position from current/recent activity");
        }

        if (loc == null) {
            var weather = Weather.getCurrentConditions();
            if (weather != null) {
                loc = erase(weather).observationLocationPosition;
                // Note: altitude not provided
                System.println("Found position from current weather conditions");
            }
        }

        if (loc != null) {
            var coords = loc.toRadians();
            var latitude = coords[0].toFloat();
            var longitude = coords[1].toFloat();
            return new Location3(latitude, longitude, altitude);
        }
        else {
            return null;
        }
    }
}