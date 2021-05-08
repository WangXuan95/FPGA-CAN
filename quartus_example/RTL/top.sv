module top(
    // Clocks
    input  wire           CLK50M,
    // LED
    //output reg  [ 3:0]    LED,
    // USB-UART
    //input  wire           UART_RX,
    output wire           UART_TX,
    // CAN bus
    input  wire           CAN_RX,  // IOA[0]
    output wire           CAN_TX   // IOA[1]
);

wire clk = CLK50M;  // 50 MHz (maybe you can set a frequency close to but not equal to 50 MHz, like 50.5MHz, for testing the robust of CAN's clock retiming).
wire rstn;

reg [31:0] can_tx_cnt;
reg        can_tx_valid;
reg [31:0] can_tx_data;

wire       can_rx_valid;
wire [7:0] can_rx_data;


// --------------------------------------------------------------------------------------------------------------
//  power on reset generate
// --------------------------------------------------------------------------------------------------------------
reset_gen #(
    .DEFAULT         ( 1                    ),
    .tP              ( 25000                ),
    .tR              ( 25000                )
) reset_gen_i (
    .rstn            ( 1'b1                 ),
    .clk             ( clk                  ),
    .on              ( 1'b0                 ),
    .off             ( 1'b0                 ),
    .o_pwr           (                      ),
    .o_rst           ( rstn                 ),
    .o_rst_aux       (                      )
);



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
    .rstn            ( rstn                 ),
    .clk             ( clk                  ),
    
    .can_rx          ( CAN_RX               ),
    .can_tx          ( CAN_TX               ),
    
    .tx_valid        ( can_tx_valid         ),
    .tx_ready        (                      ),
    .tx_data         ( can_tx_data          ),
    
    .rx_valid        ( can_rx_valid         ),
    .rx_last         (                      ),
    .rx_data         ( can_rx_data          ),
    .rx_id           (                      ),
    .rx_ide          (                      )
);


// --------------------------------------------------------------------------------------------------------------
//  UART TX for CAN RX
// --------------------------------------------------------------------------------------------------------------
uart_tx #(
    .UART_CLK_DIV    ( 434                  ),
    .FIFO_ASIZE      ( 11                   ),
    .BYTE_WIDTH      ( 1                    ),
    .MODE            ( 0                    ),
    .BIG_ENDIAN      ( 0                    )
) uart_tx_i (
    .rstn            ( rstn                 ),
    .clk             ( clk                  ),
    .wreq            ( can_rx_valid         ),
    .wgnt            (                      ),
    .wdata           ( can_rx_data          ),
    .o_uart_tx       ( UART_TX              )
);

endmodule
