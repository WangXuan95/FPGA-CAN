`timescale 1ps/1ps

module can_top #(
    // local ID parameter
    parameter logic [10:0] LOCAL_ID      = 11'h456,
    
    // recieve ID filter parameters
    parameter logic [10:0] RX_ID_SHORT_FILTER = 11'h123,
    parameter logic [10:0] RX_ID_SHORT_MASK   = 11'h7ff,
    parameter logic [28:0] RX_ID_LONG_FILTER  = 29'h12345678,
    parameter logic [28:0] RX_ID_LONG_MASK    = 29'h1fffffff,
    
    // CAN timing parameters
    parameter logic [15:0] default_c_PTS  = 16'd34,
    parameter logic [15:0] default_c_PBS1 = 16'd5,
    parameter logic [15:0] default_c_PBS2 = 16'd10
) (
    input  wire        rstn,  // set to 1 while working
    input  wire        clk,   // system clock
    
    // CAN TX and RX, connect to external CAN phy (e.g., TJA1050)
    input  wire        can_rx,
    output wire        can_tx,
    
    // user tx-buffer write interface
    input  wire        tx_valid,  // when tx_valid=1 and tx_ready=1, push a data to tx fifo
    output wire        tx_ready,  // whether the tx fifo is available
    input  wire [31:0] tx_data,   // the data to push to tx fifo
    
    // user rx data interface (byte per cycle, unbuffered)
    output reg         rx_valid,  // whether data byte is valid
    output reg         rx_last,   // indicate the last data byte of a packet
    output reg  [ 7:0] rx_data,   // a data byte in the packet
    output reg  [28:0] rx_id,     // the ID of a packet
    output reg         rx_ide     // whether the ID is LONG or SHORT
);

wire        buff_valid;
reg         buff_ready;
wire [31:0] buff_data;

reg         pkt_txing;
reg  [31:0] pkt_tx_data;
wire        pkt_tx_done;
wire        pkt_tx_acked;
wire        pkt_rx_valid;
wire [28:0] pkt_rx_id;
wire        pkt_rx_ide;
wire        pkt_rx_rtr;
wire [ 3:0] pkt_rx_len;
wire [63:0] pkt_rx_data;
reg         pkt_rx_ack;

reg         t_rtr_req;
reg         r_rtr_req;
reg  [ 3:0] r_cnt;
reg  [ 3:0] r_len;
reg  [63:0] r_data;
reg  [ 1:0] t_retry_cnt;


// ---------------------------------------------------------------------------------------------------------------------------------------
//  TX buffer
// ---------------------------------------------------------------------------------------------------------------------------------------
can_tx_fifo #(
    .AWIDTH          ( 10               ),
    .DWIDTH          ( 32               )
) can_tx_buffer (
    .rstn            ( rstn             ),
    .clk             ( clk              ),
    .emptyn          (                  ),
    .itvalid         ( tx_valid         ),
    .itready         ( tx_ready         ),
    .itdata          ( tx_data          ),
    .otvalid         ( buff_valid       ),
    .otready         ( buff_ready       ),
    .otdata          ( buff_data        )
);


// ---------------------------------------------------------------------------------------------------------------------------------------
//  CAN packet level controller
// ---------------------------------------------------------------------------------------------------------------------------------------
can_level_packet #(
    .TX_ID           ( LOCAL_ID         ),
    .default_c_PTS   ( default_c_PTS    ),
    .default_c_PBS1  ( default_c_PBS1   ),
    .default_c_PBS2  ( default_c_PBS2   )
) can_level_packet_i (
    .rstn            ( rstn             ),
    .clk             ( clk              ),
    
    .can_rx          ( can_rx           ),
    .can_tx          ( can_tx           ),
    
    .tx_start        ( pkt_txing        ),
    .tx_data         ( pkt_tx_data      ),
    .tx_done         ( pkt_tx_done      ),
    .tx_acked        ( pkt_tx_acked     ),
    
    .rx_valid        ( pkt_rx_valid     ),
    .rx_id           ( pkt_rx_id        ),
    .rx_ide          ( pkt_rx_ide       ),
    .rx_rtr          ( pkt_rx_rtr       ),
    .rx_len          ( pkt_rx_len       ),
    .rx_data         ( pkt_rx_data      ),
    .rx_ack          ( pkt_rx_ack       )
);


// ---------------------------------------------------------------------------------------------------------------------------------------
//  RX action
// ---------------------------------------------------------------------------------------------------------------------------------------
always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        pkt_rx_ack <= 1'b0;
        r_rtr_req <= 1'b0;
        r_cnt <= 4'd0;
        r_len <= 4'd0;
        r_data <= '0;
        {rx_valid, rx_last, rx_data, rx_id, rx_ide} <= '0;
    end else begin
        {rx_valid, rx_last, rx_data} <= '0;
        
        pkt_rx_ack <= 1'b0;
        r_rtr_req <= 1'b0;
        
        if(r_cnt>4'd0) begin             // send the data bytes out

            rx_valid <= (r_cnt<=r_len);
            rx_last  <= (r_cnt<=r_len) && (r_cnt==4'd1);
            {rx_data, r_data} <= {r_data, 8'd0};
            r_cnt <= r_cnt - 4'd1;
            
        end else if(pkt_rx_valid) begin  // recieve a new packet
        
            r_len <= pkt_rx_len;             // latches the rx_len
            r_data <= pkt_rx_data;           // latches the rx_data
            
            if(pkt_rx_rtr) begin
                if(~pkt_rx_ide && pkt_rx_id[10:0]==LOCAL_ID) begin                                           // is a short-ID remote packet, and the ID matches LOCAL_ID
                    pkt_rx_ack <= 1'b1;
                    r_rtr_req <= 1'b1;
                end
            end else if(~pkt_rx_ide) begin                                                                   // is a short-ID data packet
                if( (pkt_rx_id[10:0] & RX_ID_SHORT_MASK) == (RX_ID_SHORT_FILTER & RX_ID_SHORT_MASK) ) begin  // ID match
                    pkt_rx_ack <= 1'b1;
                    r_cnt <= 4'd8;
                    rx_id <= pkt_rx_id;
                    rx_ide <= pkt_rx_ide;
                end
            end else begin                                                                                   // is a long-ID data packet
                if( (pkt_rx_id & RX_ID_LONG_MASK) == (RX_ID_LONG_FILTER & RX_ID_LONG_MASK) ) begin           // ID match
                    pkt_rx_ack <= 1'b1;
                    r_cnt <= 4'd8;
                    rx_id <= pkt_rx_id;
                    rx_ide <= pkt_rx_ide;
                end
            end
        end
    end


// ---------------------------------------------------------------------------------------------------------------------------------------
//  TX action
// ---------------------------------------------------------------------------------------------------------------------------------------
always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        buff_ready <= 1'b0;
        pkt_tx_data <= '0;
        t_rtr_req <= 1'b0;
        pkt_txing <= 1'b0;
        t_retry_cnt <= 2'd0;
    end else begin
        buff_ready <= 1'b0;
        
        if(r_rtr_req)
            t_rtr_req <= 1'b1;                   // set t_rtr_req 
        
        if(~pkt_txing) begin
            t_retry_cnt <= 2'd0;
            if(t_rtr_req | buff_valid) begin     // if recieved a remote packet, or tx-buffer data available
                buff_ready <= buff_valid;        // tx-buffer buffer pop, if tx-buffer is available
                t_rtr_req <= 1'b0;               // reset t_rtr_req 
                if(buff_valid)                   // update data from tx-buffer , if tx-buffer is available
                    pkt_tx_data <= buff_data;
                pkt_txing <= 1'b1;
            end
        end else if(pkt_tx_done) begin
            if(pkt_tx_acked || t_retry_cnt==2'd3) begin
                pkt_txing <= 1'b0;
            end else begin
                t_retry_cnt <= t_retry_cnt + 2'd1;
            end
        end
    end

endmodule
