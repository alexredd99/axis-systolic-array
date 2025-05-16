#!/bin/zsh
yosys -c tcl/synth.tcl --\
    MacType=1\
    Rows=1\
    Cols=10\
    ExpWidthX=4\
    ExpWidthK=4\
    ManWidthX=3\
    ManWidthK=3\
    WidthY=64