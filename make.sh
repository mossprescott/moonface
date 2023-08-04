#! /bin/bash

set -e

cd $(dirname $0)
DIR=$(pwd)  # Should be an absolute path


#
# Run the image-conversion script each time:
#

cd "$DIR/image"

. env/bin/activate

python dither.py "$DIR"
# ls -lh "$DIR/resources/drawables"

# Note: the compiler won't detect modified resources, so force it to rebuild them:
rm -rf "$DIR/bin"


#
# Now compile and run unit tests:
#

cd "$DIR"

# PATH="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-4.2.2-2023-03-09-6ec276508/bin:$PATH"
# PATH="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-4.2.4-2023-04-05-5830cc591/bin:$PATH"

echo "Using SDK: $CONNECTIQ_HOME"
PATH="$CONNECTIQ_HOME/bin:$PATH"

DEVELOPER_KEY_PATH="$CONNECTIQ_HOME/../../../developer_key"

# See https://developer.garmin.com/connect-iq/core-topics/unit-testing/
monkeyc \
    -f monkey.jungle  \
    -o build/test/moonface.prg \
    -y  "$DEVELOPER_KEY_PATH" \
    -d fenix7_sim \
    -warn --typecheck 2 \
    --unit-test

connectiq

monkeydo build/test/moonface.prg fenix7 -t


#
# Build release binaries:
#

for device in "fenix7"; do
    echo "Building for $device..."
    monkeyc \
        -f monkey.jungle  \
        -o build/$device/moonface.prg \
        -y "$DEVELOPER_KEY_PATH" \
        -d $device \
        --optimization 2 \
        --release

    ls -lh build/$device/*.prg
done