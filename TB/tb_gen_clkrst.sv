`timescale 1ps/1ps

module tb_gen_clkrst #(
    parameter PERIOD = 10000
) (
    output reg  rstn,
    output reg  clk
);

initial rstn = 1'b0;
initial clk  = 1'b1;
always #(PERIOD) clk = ~clk;   // 50MHz
initial begin repeat(4) @(posedge clk); rstn<=1'b1; end

endmodule
