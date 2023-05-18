import Toybox.Lang;

class Throttle {
    // System milliseconds timer at the start of the current update cycle.
    private var updateStartTime as Number = System.getTimer();

    public function updateStarted() as Void {
        updateStartTime = System.getTimer();
    }

    // Estimate of the fraction of the allotted execution time which is still remaining. If this
    // ever gets close to 0, the app may be killed.
    public function getRemainingTime() as Float {
        var now = System.getTimer();

        if (now < updateStartTime) {
            // edge case: the 32-bit millis timer overflowed
            return 0.0;
        }
        else {
            var elapsedMillis = now - updateStartTime;
            // System.println(Lang.format("Elapsed: $1$ of $2$", [elapsedMillis, maxUpdateMillis()]));
            return 1.0 - elapsedMillis.toFloat()/maxUpdateMillis();
        }
    }

    (:simulator)
    private function maxUpdateMillis() as Number {
        return 50;
    }

    (:notSimulator)
    private function maxUpdateMillis() as Number {
        return 500;
    }
}