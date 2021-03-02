#!/bin/bash

# display branch history in a text tree
git log --graph --full-history --all --pretty=format:"%h%x09%d%x20%s"

# output ANSI codes for the colors, even when piping to a file
git log --color=always

# display the actual diff
git log -p
