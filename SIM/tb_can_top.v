
//--------------------------------------------------------------------------------------------------------
// Module  : tb_can_top
// Type    : simulation, top
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: testbench for can_top
//--------------------------------------------------------------------------------------------------------

`timescale 1ps/1ps

module tb_can_top();


// -----------------------------------------------------------------------------------------------------------------------------
// simulation control
// -----------------------------------------------------------------------------------------------------------------------------
initial $dumpvars(0, tb_can_top);
initial #10000000000 $finish;              // simulation for 10ms




// ---------------------------------------------------------------------------------------------------------------------------------------
//  CAN bus
// ---------------------------------------------------------------------------------------------------------------------------------------
tri      can_bus;    // can_bus = CAN_H - CAN_L
pulldown(can_bus);   // pull CAN_H to CAN_L by a resistor




// ---------------------------------------------------------------------------------------------------------------------------------------
//  CAN1 device
// ---------------------------------------------------------------------------------------------------------------------------------------
wire         can1_rstn;
wire         can1_clk;
wire         can1_rx;
wire         can1_tx;
reg   [31:0] can1_tx_cnt = 0; 
wire         can1_tx_valid;
reg   [31:0] can1_tx_data = 0;
wire         can1_rx_valid;  // whether data byte is valid
wire         can1_rx_last;   // indicate the last data byte of a packet
wire  [ 7:0] can1_rx_data;   // a data byte in the packet
wire  [28:0] can1_rx_id;     // the ID of a packet
wire         can1_rx_ide;    // whether the ID is LONG or SHORT

tb_gen_clkrst #(10100) can1_clkrst(can1_rstn, can1_clk);  // 50MHz clock, skew = +1%

tb_can_phy can1_phy(can1_tx, can1_rx, can_bus);

can_top #(
    .LOCAL_ID          ( 11'b00000000001 ), // local-id = 00000000001(1)
    .RX_ID_SHORT_FILTER( 11'b00000000010 ),
    .RX_ID_SHORT_MASK  ( 11'b11111111110 ), // dont care the last bit, i.e., acks the id 00000000010(2) and 00000000011(3)
    .RX_ID_LONG_FILTER ( 29'h12345678    ),
    .RX_ID_LONG_MASK   ( 29'h1fffffff    ),
    .default_c_PTS     ( 16'd34          ),
    .default_c_PBS1    ( 16'd5           ),
    .default_c_PBS2    ( 16'd10          )
) can1_controller (
    .rstn              ( can1_rstn       ),
    .clk               ( can1_clk        ),
    .can_rx            ( can1_rx         ),
    .can_tx            ( can1_tx         ),
    .tx_valid          ( can1_tx_valid   ),  // always try to write tx-fifo
    .tx_ready          (                 ),
    .tx_data           ( can1_tx_data    ),
    .rx_valid          ( can1_rx_valid   ),
    .rx_last           ( can1_rx_last    ),
    .rx_data           ( can1_rx_data    ),
    .rx_id             ( can1_rx_id      ),
    .rx_ide            ( can1_rx_ide     )
);

// CAN1 TX Periodically
assign can1_tx_valid = (can1_tx_cnt==80000);
always @ (posedge can1_clk or negedge can1_rstn)
    if(~can1_rstn) begin
        can1_tx_cnt <= 0;
        can1_tx_data <= 0;
    end else begin
        if(can1_tx_valid) begin
            can1_tx_cnt <= 0;
            can1_tx_data <= can1_tx_data + 1;
        end else begin
            can1_tx_cnt <= can1_tx_cnt + 1;
        end
    end

// print CAN1 receieved packet
always @ (posedge can1_clk)
    if(can1_rx_valid & can1_rx_last) begin
        $write("CAN1 recieve packet from [%08x], ", can1_rx_id);
        if(can1_rx_ide)
            $write("  LONG\n");
        else
            $write(" SHORT\n");
    end




// ---------------------------------------------------------------------------------------------------------------------------------------
//  CAN2 device
// ---------------------------------------------------------------------------------------------------------------------------------------
wire         can2_rstn;
wire         can2_clk;
wire         can2_rx;
wire         can2_tx;
reg   [31:0] can2_tx_cnt = 0; 
wire         can2_tx_valid;
reg   [31:0] can2_tx_data = 0;
wire         can2_rx_valid;  // whether data byte is valid
wire         can2_rx_last;   // indicate the last data byte of a packet
wire  [ 7:0] can2_rx_data;   // a data byte in the packet
wire  [28:0] can2_rx_id;     // the ID of a packet
wire         can2_rx_ide;    // whether the ID is LONG or SHORT

tb_gen_clkrst #(9900) can2_clkrst(can2_rstn, can2_clk);  // 50MHz clock, skew = -1%

tb_can_phy can2_phy(can2_tx, can2_rx, can_bus);

can_top #(
    .LOCAL_ID          ( 11'b00000000010 ), // local-id = 00000000010(2)
    .RX_ID_SHORT_FILTER( 11'b00000000011 ), // acks the id 00000000011(3)
    .RX_ID_SHORT_MASK  ( 11'b11111111111 ),
    .RX_ID_LONG_FILTER ( 29'h12345678    ),
    .RX_ID_LONG_MASK   ( 29'h1fffffff    ),
    .default_c_PTS     ( 16'd34          ),
    .default_c_PBS1    ( 16'd5           ),
    .default_c_PBS2    ( 16'd10          )
) can2_controller (
    .rstn              ( can2_rstn       ),
    .clk               ( can2_clk        ),
    .can_rx            ( can2_rx         ),
    .can_tx            ( can2_tx         ),
    .tx_valid          ( can2_tx_valid   ),  // always try to write tx-fifo
    .tx_ready          (                 ),
    .tx_data           ( can2_tx_data    ),
    .rx_valid          ( can2_rx_valid   ),
    .rx_last           ( can2_rx_last    ),
    .rx_data           ( can2_rx_data    ),
    .rx_id             ( can2_rx_id      ),
    .rx_ide            ( can2_rx_ide     )
);

// CAN2 TX Periodically
assign can2_tx_valid = (can2_tx_cnt==50000);
always @ (posedge can2_clk or negedge can2_rstn)
    if(~can2_rstn) begin
        can2_tx_cnt <= 0;
        can2_tx_data <= 0;
    end else begin
        if(can2_tx_valid) begin
            can2_tx_cnt <= 0;
            can2_tx_data <= can2_tx_data + 1;
        end else begin
            can2_tx_cnt <= can2_tx_cnt + 1;
        end
    end

// print CAN2 receieved packet
always @ (posedge can2_clk)
    if(can2_rx_valid & can2_rx_last) begin
        $write("CAN2 recieve packet from [%08x], ", can2_rx_id);
        if(can2_rx_ide)
            $write("  LONG\n");
        else
            $write(" SHORT\n");
    end




// ---------------------------------------------------------------------------------------------------------------------------------------
//  CAN3 device
// ---------------------------------------------------------------------------------------------------------------------------------------
wire         can3_rstn;
wire         can3_clk;
wire         can3_rx;
wire         can3_tx;
reg   [31:0] can3_tx_cnt = 0; 
wire         can3_tx_valid;
reg   [31:0] can3_tx_data = 0;
wire         can3_rx_valid;  // whether data byte is valid
wire         can3_rx_last;   // indicate the last data byte of a packet
wire  [ 7:0] can3_rx_data;   // a data byte in the packet
wire  [28:0] can3_rx_id;     // the ID of a packet
wire         can3_rx_ide;    // whether the ID is LONG or SHORT

tb_gen_clkrst #(10000) can3_clkrst(can3_rstn, can3_clk);  // 50MHz clock, skew = 0%

tb_can_phy can3_phy(can3_tx, can3_rx, can_bus);

can_top #(
    .LOCAL_ID          ( 11'b00000000011 ), // local-id = 00000000011(3)
    .RX_ID_SHORT_FILTER( 11'b00000000100 ), // acks the id 00000000100(4)
    .RX_ID_SHORT_MASK  ( 11'b11111111111 ),
    .RX_ID_LONG_FILTER ( 29'h12345678    ),
    .RX_ID_LONG_MASK   ( 29'h1fffffff    ),
    .default_c_PTS     ( 16'd34          ),
    .default_c_PBS1    ( 16'd5           ),
    .default_c_PBS2    ( 16'd10          )
) can3_controller (
    .rstn              ( can3_rstn       ),
    .clk               ( can3_clk        ),
    .can_rx            ( can3_rx         ),
    .can_tx            ( can3_tx         ),
    .tx_valid          ( can3_tx_valid   ),  // always try to write tx-fifo
    .tx_ready          (                 ),
    .tx_data           ( can3_tx_data    ),
    .rx_valid          ( can3_rx_valid   ),
    .rx_last           ( can3_rx_last    ),
    .rx_data           ( can3_rx_data    ),
    .rx_id             ( can3_rx_id      ),
    .rx_ide            ( can3_rx_ide     )
);

// CAN3 TX Periodically
assign can3_tx_valid = (can3_tx_cnt==60000);
always @ (posedge can3_clk or negedge can3_rstn)
    if(~can3_rstn) begin
        can3_tx_cnt <= 0;
        can3_tx_data <= 0;
    end else begin
        if(can3_tx_valid) begin
            can3_tx_cnt <= 0;
            can3_tx_data <= can3_tx_data + 1;
        end else begin
            can3_tx_cnt <= can3_tx_cnt + 1;
        end
    end

// print CAN3 receieved packet
always @ (posedge can3_clk)
    if(can3_rx_valid & can3_rx_last) begin
        $write("CAN3 recieve packet from [%08x], ", can3_rx_id);
        if(can3_rx_ide)
            $write("  LONG\n");
        else
            $write(" SHORT\n");
    end




// ---------------------------------------------------------------------------------------------------------------------------------------
//  CAN4 device
// ---------------------------------------------------------------------------------------------------------------------------------------
wire         can4_rstn;
wire         can4_clk;
wire         can4_rx;
wire         can4_tx;
reg   [31:0] can4_tx_cnt = 0; 
wire         can4_tx_valid;
reg   [31:0] can4_tx_data = 0;
wire         can4_rx_valid;  // whether data byte is valid
wire         can4_rx_last;   // indicate the last data byte of a packet
wire  [ 7:0] can4_rx_data;   // a data byte in the packet
wire  [28:0] can4_rx_id;     // the ID of a packet
wire         can4_rx_ide;    // whether the ID is LONG or SHORT

tb_gen_clkrst #(9900) can4_clkrst(can4_rstn, can4_clk);  // 50MHz clock, skew = -1%

tb_can_phy can4_phy(can4_tx, can4_rx, can_bus);

can_top #(
    .LOCAL_ID          ( 11'b00000000100 ), // local-id = 00000000100(4)
    .RX_ID_SHORT_FILTER( 11'b00000000001 ), // acks the id 00000000001(1)
    .RX_ID_SHORT_MASK  ( 11'b11111111111 ),
    .RX_ID_LONG_FILTER ( 29'h12345678    ),
    .RX_ID_LONG_MASK   ( 29'h1fffffff    ),
    .default_c_PTS     ( 16'd34          ),
    .default_c_PBS1    ( 16'd5           ),
    .default_c_PBS2    ( 16'd10          )
) can4_controller (
    .rstn              ( can4_rstn       ),
    .clk               ( can4_clk        ),
    .can_rx            ( can4_rx         ),
    .can_tx            ( can4_tx         ),
    .tx_valid          ( can4_tx_valid   ),  // always try to write tx-fifo
    .tx_ready          (                 ),
    .tx_data           ( can4_tx_data    ),
    .rx_valid          ( can4_rx_valid   ),
    .rx_last           ( can4_rx_last    ),
    .rx_data           ( can4_rx_data    ),
    .rx_id             ( can4_rx_id      ),
    .rx_ide            ( can4_rx_ide     )
);

// CAN4 TX Periodically
assign can4_tx_valid = (can4_tx_cnt==50000);
always @ (posedge can4_clk or negedge can4_rstn)
    if(~can4_rstn) begin
        can4_tx_cnt <= 0;
        can4_tx_data <= 0;
    end else begin
        if(can4_tx_valid) begin
            can4_tx_cnt <= 0;
            can4_tx_data <= can4_tx_data + 1;
        end else begin
            can4_tx_cnt <= can4_tx_cnt + 1;
        end
    end

// print CAN4 receieved packet
always @ (posedge can4_clk)
    if(can4_rx_valid & can4_rx_last) begin
        $write("CAN4 recieve packet from [%08x], ", can4_rx_id);
        if(can4_rx_ide)
            $write("  LONG\n");
        else
            $write(" SHORT\n");
    end


endmodule






// ---------------------------------------------------------------------------------------------------------------------------------------
//  Module: Generate Clock and reset
// ---------------------------------------------------------------------------------------------------------------------------------------
module tb_gen_clkrst #(
    parameter PERIOD = 10000
) (
    output reg  rstn,
    output reg  clk
);

initial rstn = 1'b0;
initial clk  = 1'b1;
always #(PERIOD) clk = ~clk;
initial begin repeat(4) @(posedge clk); rstn<=1'b1; end

endmodule






// ---------------------------------------------------------------------------------------------------------------------------------------
//  Module: simulate CAN-phy chips, e.g., TJA1050
// ---------------------------------------------------------------------------------------------------------------------------------------
module tb_can_phy(
    input  wire    can_tx,
    output wire    can_rx,
    inout          can_bus    // can_bus = CAN_H - CAN_L
);

assign can_bus = can_tx ? 1'bz : 1'b1;
assign can_rx = ~can_bus;

endmodule
