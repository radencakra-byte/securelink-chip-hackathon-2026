module top_echo #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD     = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       uart_rx_pin,
    output wire       uart_tx_pin,
    output wire [3:0] led
);
    wire [7:0] rx_data;
    wire       rx_valid, rx_err;

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) u_rx (
        .clk(clk), .rst_n(rst_n), .rx(uart_rx_pin),
        .data(rx_data), .valid(rx_valid), .frame_err(rx_err));

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) u_tx (
        .clk(clk), .rst_n(rst_n), .data(rx_data), .start(rx_valid),
        .tx(uart_tx_pin), .busy());

    
    reg [31:0] hb_cnt;
    reg        hb;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin hb_cnt <= 0; hb <= 1'b0; end
        else if (hb_cnt == CLK_FREQ/2 - 1) begin hb_cnt <= 0; hb <= ~hb; end
        else hb_cnt <= hb_cnt + 1;
    end
    
    assign led = ~{hb, rx_data[2:0]};
endmodule
