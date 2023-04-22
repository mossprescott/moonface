#! /bin/bash

set -e

cd $(dirname $0)
DIR=$(pwd)  # Should be an absolute path


#
# Run the image-conversion script each time:
#

cd "$DIR/image"

. env/bin/activate
python convert.py > "$DIR/resources/jsonData/moonPixels.json"
ls -lh "$DIR/resources/jsonData"

# Note: the compiler won't detect a modified resource file, so manually delete build/ when changes are made


#
# Now compile and run unit tests:
#

cd "$DIR"

PATH="$PATH:$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-4.2.2-2023-03-09-6ec276508/bin"

# See https://developer.garmin.com/connect-iq/core-topics/unit-testing/
monkeyc \
    -f monkey.jungle  \
    -o build/test/moonface.prg \
    -y "$HOME/Developer/Garmin/developer_key" \
    -d fenix7_sim \
    -w -l 2 \
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
        -y "$HOME/Developer/Garmin/developer_key" \
        -d $device \
        --release

    ls -lh build/$device/*.prg
done