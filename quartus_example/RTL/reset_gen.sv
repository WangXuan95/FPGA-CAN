module reset_gen #(
    parameter  DEFAULT      = 0,           // 1=default on , 0=default off
    parameter  RESETHL      = 0,           // 0=active low reset, 1=active high reset
    parameter  RESETHL_AUX  = 0,           // 0=active low reset, 1=active high reset
    parameter  tP           = 10000000,
    parameter  tR           = 10000000
) (
    // clock and reset
    input  wire     rstn, clk,
    // control
    input  wire     on , off,
    // power and reset pins
    output wire     o_pwr, o_rst, o_rst_aux
);

localparam  tA = 1               ,
            tB = 1 + tP          ,
            tC = 1 + tP + tR     ,
            tD = 1 + tP + tR + 1 ;

reg [ 1:0] out;
reg [31:0] cnt;

assign o_pwr     = out[1];
assign o_rst     = RESETHL     ? ~out[0] : out[0];
assign o_rst_aux = RESETHL_AUX ? ~out[0] : out[0];

always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        out <= 2'b00;
        cnt <= 0;
    end else begin
        if          ( off ) begin
            out <= 2'b00;
            cnt <= tD;
        end else if ( on  ) begin
            out <= 2'b00;
            cnt <= tA;
        end else if ( cnt < tA ) begin
            out <= 2'b00;
            cnt <= DEFAULT ? tA : tD;
        end else if ( cnt < tB ) begin
            out <= 2'b00;
            cnt <= cnt + 1;
        end else if ( cnt < tC ) begin
            out <= 2'b10;
            cnt <= cnt + 1;
        end else if ( cnt < tD ) begin
            out <= 2'b11;
            cnt <= cnt + 1;
        end else if ( cnt > tD ) begin
            out <= 2'b00;
            cnt <= 0;
        end
    end

endmodule
