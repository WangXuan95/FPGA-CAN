`timescale 1ps/1ps

module can_level_bit #(
    parameter logic [15:0] default_c_PTS  = 16'd34,
    parameter logic [15:0] default_c_PBS1 = 16'd5,
    parameter logic [15:0] default_c_PBS2 = 16'd10
) (
    input  wire        rstn,  // set to 1 while working
    input  wire        clk,   // system clock, eg, when clk=50000kHz, can baud rate = 50000/(1+default_c_PTS+default_c_PBS1+default_c_PBS2) = 100kHz
    
    // CAN TX and RX
    input  wire        can_rx,
    output reg         can_tx,
    
    // user interface
    output reg         req,   // indicate the bit border
    output reg         rbit,  // last bit recieved, valid when req=1
    input  wire        tbit   // next bit to transmit, must set at the cycle after req=1
);


reg        rx_buf;
reg        rx_fall;
always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        rx_buf  <= 1'b1;
        rx_fall <= 1'b0;
    end else begin
        rx_buf  <= can_rx;
        rx_fall <= rx_buf & ~can_rx;
    end

localparam [16:0] default_c_PTS_e  = {1'b0, default_c_PTS};
localparam [16:0] default_c_PBS1_e = {1'b0, default_c_PBS1};
localparam [16:0] default_c_PBS2_e = {1'b0, default_c_PBS2};

reg  [16:0] adjust_c_PBS1;
reg  [ 2:0] cnt_high;
reg  [16:0] cnt;
enum logic [1:0] {STAT_PTS, STAT_PBS1, STAT_PBS2} stat;
reg        inframe;


always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        can_tx <= 1'b1;
        req <= 1'b0;
        rbit <= 1'b1;
        adjust_c_PBS1 <= 8'd0;
        cnt_high <= 3'd0;
        cnt <= 17'd1;
        stat <= STAT_PTS;
        inframe <= 1'b0;
    end else begin
        req <= 1'b0;
        if(~inframe & rx_fall) begin
            adjust_c_PBS1 <= default_c_PBS1_e;
            cnt <= 17'd1;
            stat <= STAT_PTS;
            inframe <= 1'b1;
        end else begin
            case(stat)
                STAT_PTS: begin
                    if( (rx_fall & tbit) && cnt>17'd2 )
                        adjust_c_PBS1 <= default_c_PBS1_e + cnt;
                    if(cnt>=default_c_PTS_e) begin
                        cnt <= 17'd1;
                        stat <= STAT_PBS1;
                    end else
                        cnt <= cnt + 17'd1;
                end
                STAT_PBS1: begin
                    if(cnt==17'd1) begin
                        req <= 1'b1;
                        rbit <= rx_buf;   // sampling bit
                        cnt_high <= rx_buf ? cnt_high<3'd7 ? cnt_high+3'd1 : cnt_high : 3'd0;
                    end
                    if(cnt>=adjust_c_PBS1) begin
                        cnt <= 17'd0;
                        stat <= STAT_PBS2;
                    end else
                        cnt <= cnt + 17'd1;
                end
                STAT_PBS2: begin
                    if( (rx_fall & tbit) || (cnt>=default_c_PBS2_e) ) begin
                        can_tx <= tbit;
                        adjust_c_PBS1 <= default_c_PBS1_e;
                        cnt <= 17'd1;
                        stat <= STAT_PTS;
                        if(cnt_high==3'd7) inframe <= 1'b0;
                    end else begin
                        cnt <= cnt + 17'd1;
                        if(cnt==default_c_PBS2_e-17'd1)
                            can_tx <= tbit;
                    end
                end
                default : begin
                    stat <= STAT_PTS;
                end
            endcase
        end
    end

endmodule
