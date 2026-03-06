#!/bin/bash

run() {
	exec=$1
	printf "\x1b[38;5;104m --> ${exec}\x1b[39m\n"
	eval ${exec}
}

say() {
	say=$1
	printf "\x1b[38;5;220m${say}\x1b[38;5;255m\n"
}

say "Installing Prerequisites"
run "pip3 install luma.oled"
run "apt install -y fonts-terminus fonts-terminus-otb fonts-dejavu fonts-noto-mono fonts-spleen"

say "Installing SVXLink OLED Service"
run "cp svxoled.service /etc/systemd/system/svxoled.service"
run "systemctl enable svxoled.service"
