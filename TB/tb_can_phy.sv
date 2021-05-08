`timescale 1ps/1ps


// for simulating CAN-phy chips, e.g., TJA1050
module tb_can_phy(
    input  wire    can_tx,
    output wire    can_rx,
    inout          can_bus    // can_bus = CAN_H - CAN_L
);

assign can_bus = can_tx ? 1'bz : 1'b1;
assign can_rx = ~can_bus;

endmodule