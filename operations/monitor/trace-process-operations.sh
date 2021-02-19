#!/bin/bash

# for a running process
strace -p 1234

# when executing a command from the shell
strace abc

# list file IO
strace -p 1234 -e file
