#! /bin/bash

# Note: probably will clobber previous virtual env

python3 -m venv env
. env/bin/activate
pip install Pillow
pip install numpy
