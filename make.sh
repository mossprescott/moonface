#! /bin/bash

set -e

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