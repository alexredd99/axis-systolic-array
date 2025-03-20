set XIL_PATH=F:\Xilinx\Vivado\2022.2\bin
set TB_MODULE=top_tb

set R=8
set C=4
set K=16
set VALID_PROB=1000
set READY_PROB=1000

SETLOCAL EnableDelayedExpansion
mkdir "build\data"
cd build
set DIR_BACKSLASH="%CD%/data/"
set "DIR=%DIR_BACKSLASH:\=/%"

call %XIL_PATH%\xsc ../../c/sim.c --gcc_compile_options -I%DIR_BACKSLASH% --gcc_compile_options -DSIM --gcc_compile_options "-DDIR=%DIR%" || exit /b !ERRORLEVEL!
call %XIL_PATH%\xvlog -sv -d "DIR=%DIR%" -d "R=%R%" -d "C=%C%" -d "VALID_PROB=%VALID_PROB%" -d "READY_PROB=%READY_PROB%"  -f ../sources.txt -i ../ || exit /b !ERRORLEVEL!
call %XIL_PATH%\xelab %TB_MODULE% --snapshot %TB_MODULE% -log elaborate.log --debug typical -sv_lib dpi || exit /b !ERRORLEVEL!
call %XIL_PATH%\xsim %TB_MODULE% --tclbatch ../xsim_cfg.tcl