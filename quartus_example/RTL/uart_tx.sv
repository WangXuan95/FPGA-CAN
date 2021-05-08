
module uart_tx #(
    parameter  UART_CLK_DIV = 434,  // UART baud rate = clk freq/(2*UART_TX_CLK_DIV)
                                    // modify UART_TX_CLK_DIV to change the UART baud
                                    // for example, when clk=50MHz, UART_TX_CLK_DIV=434, then baud=50MHz/(2*434)=115200
                                    // 115200 is a typical SPI baud rate for UART
    
    parameter  FIFO_ASIZE   = 9,    // UART TX buffer size = BYTE_WIDTH*2^FIFO_ASIZE bytes, Set it smaller if your FPGA doesn't have enough BRAM
    
    parameter  BYTE_WIDTH   = 1,
    
    parameter  MODE         = 0,    // MODE=0 : normal mode, all bytes in fifo will be send
                                    // MODE=1 : ASCII printable mode, Similar to normal mode, but ignore and skip NON-printable characters (except \r\n)
                                    // MODE=2 : HEX mode, parse raw-byte to printable-HEX and send, for example, a byte 'A' is send as '41 ' because the ASCII code of 'A' is 0x41
                                    // MODE=3 : HEX mode, Similar to normal mode2, but add \n at start of line
                                    
    parameter  BIG_ENDIAN   = 0     // 0=little endian, 1=big endian
                                    // when BYTE_WIDTH>=2, this parameter determines the byte order of wdata
)(
    input  logic clk, rstn,
    
    input  logic wreq,
    output logic wgnt,
    input  logic [BYTE_WIDTH*8-1:0] wdata,
    
    output logic o_uart_tx
);

function automatic logic [7:0] hex2ascii(input [3:0] hex);
    return (hex<4'hA) ? (hex+"0") : (hex+("A"-8'hA)) ;
endfunction

initial o_uart_tx = 1'b1;

logic rd_ena = 1'b0;
logic [FIFO_ASIZE-1:0] fifo_rd_pointer=0, fifo_wr_pointer=0;
logic [31:0] cyccnt=0, bytecnt=0, txcnt=0;
logic [31:0] tx_shift = 'hffffffff;
logic [BYTE_WIDTH*8-1:0] fifo_rd_data, fifo_rd_data_reg=0;
logic [ 7:0] bytetosend = 8'h0;

wire  [FIFO_ASIZE-1:0] fifo_wr_pointer_next = fifo_wr_pointer+1;
wire  fifo_empty_n = (fifo_wr_pointer      != fifo_rd_pointer);
wire  fifo_full_n  = (fifo_wr_pointer_next != fifo_rd_pointer);

assign wgnt = fifo_full_n & wreq;

always @ (posedge clk or negedge rstn)
    if(~rstn)
        fifo_wr_pointer = 0;
    else begin
        if(wgnt)
            fifo_wr_pointer++;
    end

always @ (posedge clk or negedge rstn)
    if(~rstn)
        cyccnt = 0;
    else
        cyccnt = (cyccnt<UART_CLK_DIV-1) ? cyccnt+1 : 0;

always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        rd_ena          = 1'b0;
        fifo_rd_pointer = 0;
        fifo_rd_data_reg= 0;
        bytetosend      = 8'h0;
        o_uart_tx       = 1'b1;
        tx_shift        = 'hffffffff;
        txcnt           = 0;
        bytecnt         = 0;
    end else begin
        if(rd_ena)
            fifo_rd_data_reg = fifo_rd_data;
        rd_ena          = 1'b0;
        if(bytecnt>0 || txcnt>0) begin
            if(cyccnt==UART_CLK_DIV-1) begin
                if(txcnt>0) begin
                    {tx_shift, o_uart_tx} = {1'b1, tx_shift};
                    txcnt--;
                end else begin
                    o_uart_tx = 1'b1;
                    bytecnt--;
                    if(BIG_ENDIAN>0)
                        bytetosend = fifo_rd_data_reg[(BYTE_WIDTH-bytecnt-1)*8 +: 8];
                    else
                        bytetosend = fifo_rd_data_reg[            bytecnt   *8 +: 8];
                    if(MODE==2 || MODE==3) begin
                        tx_shift = {3'b111, 8'h20, 2'b01, hex2ascii(bytetosend[0+:4]), 2'b01, hex2ascii(bytetosend[4+:4]), 1'b0};
                        txcnt = 30;
                    end else if(MODE==1) begin
                        if( (bytetosend>=" " && bytetosend<="~") || bytetosend=="\r" || bytetosend=="\n" ) begin
                            tx_shift = {23'h7fffff,bytetosend,1'b0};
                            txcnt = 11;
                        end else begin
                            tx_shift= 'hffffffff;
                            txcnt   = 1;
                        end
                    end else begin
                        tx_shift = {23'h7fffff,bytetosend,1'b0};
                        txcnt = 11;
                    end
                end
            end
        end else if(fifo_empty_n) begin
            o_uart_tx = 1'b1;
            bytecnt = BYTE_WIDTH;
            if(MODE==3) begin
                tx_shift = {22'h3fffff,8'd10,2'b01};
                txcnt   = 10;
            end else begin
                txcnt   = 0;
            end
            rd_ena  = 1'b1;
            fifo_rd_pointer++;
        end
    end

ram_for_uart_tx #(
    .ADDR_LEN  ( FIFO_ASIZE       ),
    .DATA_LEN  ( BYTE_WIDTH*8     )
) ram_for_uart_tx_fifo_inst(
    .clk       ( clk              ),
    .wr_req    ( wgnt             ),
    .wr_addr   ( fifo_wr_pointer  ),
    .wr_data   ( wdata            ),
    .rd_addr   ( fifo_rd_pointer  ),
    .rd_data   ( fifo_rd_data     )
);

endmodule








module ram_for_uart_tx #(
    parameter ADDR_LEN = 12,
    parameter DATA_LEN = 8
) (
    input  logic clk,
    input  logic wr_req,
    input  logic [ADDR_LEN-1:0] rd_addr, wr_addr,
    output logic [DATA_LEN-1:0] rd_data,
    input  logic [DATA_LEN-1:0] wr_data
);

localparam  RAM_SIZE = (1<<ADDR_LEN);

logic [DATA_LEN-1:0] ram [RAM_SIZE];

initial rd_data = 0;

always @ (posedge clk)
    rd_data <= ram[rd_addr];

always @ (posedge clk)
    if(wr_req)
        ram[wr_addr] <= wr_data;

endmodule
