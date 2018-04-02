#!/bin/sh

echo "Restarting plasma"

killall plasmashell && kstart5 plasmashell 2>&1
