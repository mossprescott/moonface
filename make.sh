#! /bin/bash

set -e

PATH="$PATH:$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-4.2.2-2023-03-09-6ec276508/bin"

# See https://developer.garmin.com/connect-iq/core-topics/unit-testing/
monkeyc \
    -f monkey.jungle  \
    -o bin/moonface.prg \
    -y "$HOME/Developer/Garmin/developer_key" \
    -d fenix7_sim \
    -w -l 2 \
    --unit-test

connectiq

monkeydo bin/moonface.prg fenix7 -t
