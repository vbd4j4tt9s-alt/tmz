#!/bin/sh
# Usage: sh cfg_r158i_undo.sh < Config.lua > Config_as_before_R158i.lua
# R158i (on purpose) changed Config.lua beyond the Version line: SpeedFloor / DefaultSpeed = 20000 and the speed-curve assert. The older suites that pin "Config.lua is untouched since their base"
# (R156 run_weather_ambience.sh, R158 run_hud158.sh) read the file through this filter, which puts those lines back as they were, so they still catch any OTHER change to Config.lua.
sed -e '/^-- R158i (owner: "increase the base speed/,/^Config\.DefaultSpeed = Config\.SpeedFloor$/c\
Config.DefaultSpeed = 0' \
 -e '/^    assert(Config\.DefaultSpeed >= Config\.SpeedFloor/d' \
 -e 's/^\(    assert(Config\.SpeedMilestones\[1\]\[1\]\)==0 and \(.*\),"Speed curve must start at 0 points (R158i: the default is the speed floor, 20,000)")$/\1==Config.DefaultSpeed and \2,"Speed curve must start at the default")/'
