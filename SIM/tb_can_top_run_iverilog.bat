del sim.out dump.vcd
iverilog  -g2005-sv  -o sim.out  tb_can_top.sv  ../RTL/*.sv
vvp -n sim.out
del sim.out
pause