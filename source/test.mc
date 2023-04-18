import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

// Assert two values are equal, and include the values in the message on failure.
(:debug)
function assertEqualLog(value1 as Object, value2 as Object, logger as Logger) as Void {
    Test.assertEqualMessage(value1, value2, Lang.format("Expected $1$ == $2$", [value1, value2]));
}

// Assert two values floating point are approximately equal; within the given margin.
// The actaul and expected values, and the error, are logged to :debug regardless.
(:debug)
function assertApproximatelyEqual(value1 as Decimal, value2 as Decimal, e as Decimal, logger as Logger) as Void {
    var delta = (value2 - value1).abs();
    var msg = Lang.format("Expected $1$ == $2$ with margin $3$; actual difference: $4$", [value1, value2, e, delta]);
    logger.debug(msg);

    Test.assertMessage(delta <= e, msg);
}