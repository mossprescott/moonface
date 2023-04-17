import Toybox.Lang;
import Toybox.Test;

// Assert two values are equal, and include the values in the message on failure.
(:debug)
function assertEqualLog(value1 as Object, value2 as Object, logger as Logger) as Void {
    Test.assertEqualMessage(value1, value2, Lang.format("Expected $1$ == $2$", [value1, value2]));
}