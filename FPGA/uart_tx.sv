
//--------------------------------------------------------------------------------------------------------
// Module  : uart_tx
// Type    : synthesizable, IP's top
// Standard: SystemVerilog 2005 (IEEE1800-2005)
// Function: buffer input data and send them to UART
// UART format: 8 data bits
//--------------------------------------------------------------------------------------------------------

module uart_tx #(
    parameter CLK_DIV     = 434,       // UART baud rate = clk freq/(2*UART_TX_CLK_DIV). for example, when clk=50MHz, UART_TX_CLK_DIV=434, then baud=50MHz/(2*434)=115200
    parameter PARITY      = "NONE",    // "NONE", "ODD" or "EVEN"
    parameter ASIZE       = 10,        // UART TX buffer size = 2^ASIZE bytes, Set it smaller if your FPGA doesn't have enough BRAM
    parameter DWIDTH      = 1,         // Specify width of tx_data , that is, how many bytes can it input per clock cycle
    parameter ENDIAN      = "LITTLE",  // "LITTLE" or "BIG". when DWIDTH>=2, this parameter determines the byte order of tx_data
    parameter MODE        = "RAW",     // "RAW", "PRINTABLE", "HEX" or "HEXSPACE"
    parameter END_OF_DATA = "",        // Specify a extra send byte after each tx_data. when ="", do not send this extra byte
    parameter END_OF_PACK = ""         // Specify a extra send byte after each tx_data with tx_last=1. when ="", do not send this extra byte
)(
    input  wire                rstn,
    input  wire                clk,
    // user interface
    input  wire [DWIDTH*8-1:0] tx_data,
    input  wire                tx_last,
    input  wire                tx_en,
    output wire                tx_rdy,
    // uart tx output signal
    output reg                 o_uart_tx
);

initial o_uart_tx = 1'b1;



function automatic logic [7:0] hex2ascii (input [3:0] hex);
    return {4'h3, hex} + ((hex<4'hA) ? 8'h0 : 8'h7) ;
endfunction


function automatic logic is_printable_ascii(input [7:0] ascii);
    return (ascii>=8'h20 && ascii<8'h7F) || ascii==8'h0A || ascii==8'h0D;
endfunction


function automatic logic [11:0] build_send_byte(input [7:0] send_byte);
    if     ( PARITY == "ODD"  )
        return {1'b1, (~(^send_byte)), send_byte, 2'b01};
    else if( PARITY == "EVEN" )
        return {1'b1,   (^send_byte) , send_byte, 2'b01};
    else
        return {1'b1,           1'b1 , send_byte, 2'b01};
endfunction


function automatic logic [6+35:0] build_send_data(input [7:0] send_data);
    logic [ 5:0] dcnt = '0;
    logic [35:0] data = '1;
    if( MODE != "PRINTABLE" || is_printable_ascii(send_data) ) begin
        if( MODE == "HEXSPACE" ) begin
            dcnt += 6'd12;
            data[11:0] = build_send_byte(8'h20);
        end
        dcnt += 6'd12;
        data <<= 12;
        if( MODE == "HEX" || MODE == "HEXSPACE" ) begin
            data[11:0] = build_send_byte(hex2ascii(send_data[3:0]));
            dcnt += 6'd12;
            data <<= 12;
            data[11:0] = build_send_byte(hex2ascii(send_data[7:4]));
        end else begin
            data[11:0] = build_send_byte(send_data);
        end
    end
    return {dcnt, data};
endfunction


function automatic logic [6+35:0] build_send_eod(input send_last);
    logic [ 5:0] dcnt = '0;
    logic [35:0] data = '1;
    if( END_OF_PACK != "" && send_last ) begin
        dcnt += 6'd12;
        data[11:0] = build_send_byte((8)'(END_OF_PACK));
    end
    if( END_OF_DATA != "" ) begin
        dcnt += 6'd12;
        data <<= 12;
        data[11:0] = build_send_byte((8)'(END_OF_DATA));
    end
    return {dcnt, data};
endfunction




reg [DWIDTH*8-1:0] tx_data_endian;

always_comb
    if(ENDIAN == "BIG") begin
        for(int i=0; i<DWIDTH; i++) tx_data_endian[8*i +: 8] = tx_data[8*(DWIDTH-1-i) +: 8];
    end else
        tx_data_endian = tx_data;



reg  [31:0] cyc = 0;

always @ (posedge clk or negedge rstn)
    if(~rstn)
        cyc <= 0;
    else
        cyc <= (cyc+1<CLK_DIV) ? cyc+1 : 0;


reg          [15:0] bcnt = '0;
reg                 eod  = '0;

reg          [ 5:0] txdcnt = 0;
reg          [35:0] txdata = '1;

reg  [     ASIZE:0] fifo_wptr = '0;
reg  [     ASIZE:0] fifo_rptr = '0;

reg  [DWIDTH*8  :0] fifo_ram [1<<ASIZE];    // may automatically synthesize to BRAM

reg                 fifo_rd_en = '0;
reg  [DWIDTH*8  :0] fifo_rd_data;

reg  [DWIDTH*8-1:0] send_data = '0;
reg                 send_last = '0;

wire fifo_empty_n = fifo_rptr != fifo_wptr;
assign     tx_rdy = fifo_rptr != {~fifo_wptr[ASIZE], fifo_wptr[ASIZE-1:0]};


always @ (posedge clk or negedge rstn)
    if(~rstn)
        fifo_wptr <= '0;
    else begin
        if(tx_en & tx_rdy)
            fifo_wptr <= fifo_wptr + (ASIZE+1)'(1);
    end

always @ (posedge clk)
    if(tx_rdy)
        fifo_ram[fifo_wptr[ASIZE-1:0]] <= {tx_data_endian, tx_last};

always @ (posedge clk)
    fifo_rd_data <= fifo_ram[fifo_rptr[ASIZE-1:0]];



always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        o_uart_tx  <= 1'b1;
        bcnt       <= '0;
        eod        <= '0;
        txdcnt     <= '0;
        txdata     <= '1;
        fifo_rptr  <= '0;
        fifo_rd_en <= '0;
        {send_data, send_last} <= '0;
    end else begin
        fifo_rd_en <= '0;
        if( fifo_rd_en ) begin
            bcnt <= (16)'(DWIDTH);
            eod  <= 1'b1;
            {send_data, send_last} <= fifo_rd_data;
        end else if( txdcnt > '0 ) begin
            if( cyc+1 == CLK_DIV ) begin
                txdcnt <= txdcnt - 6'd1;
                {txdata, o_uart_tx} <= {1'b1, txdata};
            end
        end else if( bcnt > '0 ) begin
            bcnt <= bcnt - 16'd1;
            send_data <= send_data >> 8;
            {txdcnt, txdata} <= build_send_data(send_data[7:0]);
        end else if( eod ) begin
            eod <= '0;
            {txdcnt, txdata} <= build_send_eod(send_last);
        end else if( fifo_empty_n ) begin
            fifo_rptr <= fifo_rptr + (ASIZE+1)'(1);
            fifo_rd_en <= 1'b1;
        end
    end


endmodule
