using Toybox.Activity;
import Toybox.Application;
import Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.Weather;
using Toybox.Test;

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

    function initialize(latitude as Decimal, longitude as Decimal, altitude as Decimal?) {
        self.latitude = latitude.toFloat();
        self.longitude = longitude.toFloat();
        self.altitude = altitude != null ? altitude.toFloat() : null;
    }

    // Distance between 2 locations, assuming a spherical globe and ignoring altitiude.
    // See https://en.wikipedia.org/wiki/Great-circle_distance
    function greatCircleDistance(other as Location3) as Float {
        var dLambda = longitude - other.longitude;
        var dPhi = latitude - other.latitude;
        var sumPhi = latitude + other.latitude;

        var dSigma = 2.0*Math.asin(Math.sqrt(
            haversine(dPhi) +
            (1 - haversine(dPhi) - haversine(sumPhi))*haversine(dLambda))) as Float;

        // Mean radius of the earth. This is pretty darn close for moderate latitudes, and within
        // 1% everywhere.
        var rEarth = 6371.009*1000.0;
        return dSigma * rEarth;
    }

    private static function haversine(x as Float) as Float {
        var s = Math.sin(x/2) as Float;
        return s*s;
    }

    function toString() as String {
        return Lang.format("$1$°$2$ $3$°$4$ $5$m", [
            (latitude.abs()*180/Math.PI).format("%0.1f"),
            latitude < 0 ? "S" : "N",
            (longitude.abs()*180/Math.PI).format("%0.1f"),
            longitude < 0 ? "W" : "E",
            altitude != null ? altitude.format("%0.0f") : "?",
        ]);
    }
}

class Locations {
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

    private static function writeStoredLocation(loc as Location3) as Void {
        Storage.setValue(LOCATION_KEY, {
            LATITUDE_FIELD => loc.latitude,
            LONGITUDE_FIELD => loc.longitude,
            ALTITUDE_FIELD => loc.altitude
        } as Dictionary<String, Float>);
    }

    private static function readStoredLocation() as Location3 or Null {
        var stored = Storage.getValue(LOCATION_KEY) as Dictionary<String, Float>?;
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

    // See https://forums.garmin.com/developer/connect-iq/f/discussion/305484/how-best-to-get-a-gps-location-in-a-watch-face
    private static function latestLocation() as Location3 or Null {
        // First try looking for a recently completed activity. This will give an accurate location
        // when available, but it's only present for a short time.
        var loc = null;
        var altitude = null;

        var activity = Activity.getActivityInfo();
        if (activity != null) {
            System.println("Activity present");
            if (activity.currentLocation != null) {
                loc = activity.currentLocation;
                altitude = activity.altitude;
                System.println("Found position from current/recent activity");
            }
        }

        if (loc == null) {
            var weather = Weather.getCurrentConditions();
            if (weather != null) {
                loc = weather.observationLocationPosition;
                // Note: altitude not provided
                // TODO: maybe use a stored altitude as an approximate value, if the position
                // is otherwise fairly close.
                System.println("Found position from current weather conditions");
            }
        }

        if (loc != null) {
            var coords = loc.toRadians();
            var latitude = coords[0].toFloat();
            var longitude = coords[1].toFloat();
            if (altitude != null and altitude < 0.0) {
                System.println(Lang.format("Pinning negative altitude: $1$m", [altitude.format("%0.1f")]));
                altitude = 0;
            }
            var result = new Location3(latitude, longitude, altitude != null ? altitude.toFloat() : null);
            System.println(result);
            return result;
        }
        else {
            return null;
        }
    }
}

(:test)
function testDistance(logger as Test.Logger) as Boolean {
    // About 1245 miles, or 2004 km
    assertApproximatelyEqual(
        Hamden.greatCircleDistance(NewOrleans),
        2004*1000.0,
        10*1000.0,
        logger);

    // A little less than 3 miles, or 4.5 km, for these particular locations.
    var newHaven = new Location3(Orbits.toRadians(41.31), Orbits.toRadians(-72.923611), 18.0);
    assertApproximatelyEqual(
        Hamden.greatCircleDistance(newHaven),
        4.5*1000.0,
        0.5*1000.0,
        logger);

    return true;
}