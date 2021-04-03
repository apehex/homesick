#!/bin/bash

# the substitions are listed line by line, with the format:
# regex:old===>new
# regex:password=\w+==>password=3x4mpl3!

# rewrite the whole git history
bfg --replace-text substitions.txt .
