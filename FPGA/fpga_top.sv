
//--------------------------------------------------------------------------------------------------------
// Module  : fpga_top
// Type    : synthesizable, FPGA's top, IP's example design
// Standard: SystemVerilog 2005 (IEEE1800-2005)
// Function: an example of can_top
//--------------------------------------------------------------------------------------------------------

module fpga_top (
    // clock (50MHz)
    input  wire           pad_clk50m,
    // UART (TX only), 连接到电脑串口
    output wire           pad_uart_tx,
    // CAN bus, 连接到 CAN PHY
    input  wire           pad_can_rx,
    output wire           pad_can_tx
);

wire clk = pad_clk50m;  // 50 MHz (maybe you can set a frequency close to but not equal to 50 MHz, like 50.5MHz, for testing the robust of CAN's clock alignment).


// --------------------------------------------------------------------------------------------------------------
//  power on reset generate
// --------------------------------------------------------------------------------------------------------------
reg        rstn = 1'b0;
reg [ 2:0] rstn_shift = '0;
always @ (posedge clk)
    {rstn, rstn_shift} <= {rstn_shift, 1'b1};



// --------------------------------------------------------------------------------------------------------------
//  signals
// --------------------------------------------------------------------------------------------------------------
reg [31:0] can_tx_cnt;
reg        can_tx_valid;
reg [31:0] can_tx_data;

wire       can_rx_valid;
wire [7:0] can_rx_data;


// --------------------------------------------------------------------------------------------------------------
//  Periodically send incremental data to the CAN tx-buffer
// --------------------------------------------------------------------------------------------------------------
always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        can_tx_cnt <= 0;
        can_tx_valid <= 1'b0;
        can_tx_data <= 0;
    end else begin
        if(can_tx_cnt<50000000-1) begin
            can_tx_cnt <= can_tx_cnt + 1;
            can_tx_valid <= 1'b0;
        end else begin
            can_tx_cnt <= 0;
            can_tx_valid <= 1'b1;
            can_tx_data <= can_tx_data + 1;
        end
    end


// --------------------------------------------------------------------------------------------------------------
//  CAN controller
// --------------------------------------------------------------------------------------------------------------
can_top #(
    .LOCAL_ID          ( 11'h456            ),
    .RX_ID_SHORT_FILTER( 11'h123            ),
    .RX_ID_SHORT_MASK  ( 11'h7ff            ),
    .RX_ID_LONG_FILTER ( 29'h12345678       ),
    .RX_ID_LONG_MASK   ( 29'h1fffffff       ),
    .default_c_PTS     ( 16'd34             ),
    .default_c_PBS1    ( 16'd5              ),
    .default_c_PBS2    ( 16'd10             )
) can0_controller (
    .rstn              ( rstn               ),
    .clk               ( clk                ),
    
    .can_rx            ( pad_can_rx         ),
    .can_tx            ( pad_can_tx         ),
    
    .tx_valid          ( can_tx_valid       ),
    .tx_ready          (                    ),
    .tx_data           ( can_tx_data        ),
    
    .rx_valid          ( can_rx_valid       ),
    .rx_last           (                    ),
    .rx_data           ( can_rx_data        ),
    .rx_id             (                    ),
    .rx_ide            (                    )
);


// --------------------------------------------------------------------------------------------------------------
//  send CAN RX data to UART TX
// --------------------------------------------------------------------------------------------------------------
uart_tx #(
    .CLK_DIV           ( 434                ),
    .PARITY            ( "NONE"             ),
    .ASIZE             ( 11                 ),
    .DWIDTH            ( 1                  ),
    .ENDIAN            ( "LITTLE"           ),
    .MODE              ( "RAW"              ),
    .END_OF_DATA       ( ""                 ),
    .END_OF_PACK       ( ""                 )
) uart_tx_i (
    .rstn              ( rstn               ),
    .clk               ( clk                ),
    .tx_data           ( can_rx_data        ),
    .tx_last           ( 1'b0               ),
    .tx_en             ( can_rx_valid       ),
    .tx_rdy            (                    ),
    .o_uart_tx         ( pad_uart_tx        )
);


endmodule
