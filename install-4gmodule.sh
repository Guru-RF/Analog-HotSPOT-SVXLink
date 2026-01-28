#!/bin/bash

run() {
  exec=$1
  printf "\x1b[38;5;104m --> ${exec}\x1b[39m\n"
  eval ${exec}
}

say () {
  say=$1
  printf "\x1b[38;5;220m${say}\x1b[38;5;255m\n"
}


say "Installing Prerequisites"
run "rm -f /usr/lib/python3.11/EXTERNALLY-MANAGED"
run "python3 -m pip install pyserial"

