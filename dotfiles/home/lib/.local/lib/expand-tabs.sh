#!/bin/sh

find . -type f -name '*.py' -exec bash -c 'expand -i -t 4 "$0" > ./.tmp.py && mv ./.tmp.py "$0"' {} \;
rm ./.tmp.py