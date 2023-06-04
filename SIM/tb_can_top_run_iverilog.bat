del sim.out dump.vcd
iverilog  -g2001  -o sim.out  ./tb_can_top.v  ../RTL/*.v
vvp -n sim.out
del sim.out
pause