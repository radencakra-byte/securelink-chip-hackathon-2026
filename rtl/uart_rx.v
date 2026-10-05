module uart_rx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD     = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        valid,
    output reg        frame_err
);
    localparam integer CPB  = CLK_FREQ / BAUD;
    localparam integer HALF = CPB / 2;
    localparam [1:0] S_IDLE = 2'd0, S_START = 2'd1, S_DATA = 2'd2, S_STOP = 2'd3;

    reg rx_s1, rx_s2;
    always @(posedge clk) begin
        rx_s1 <= rx;
        rx_s2 <= rx_s1;
    end

    reg [1:0]  state;
    reg [15:0] cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shreg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; cnt <= 0; bit_idx <= 0;
            shreg <= 0; data <= 0; valid <= 0; frame_err <= 0;
        end else begin
            valid <= 1'b0;
            case (state)
                S_IDLE: begin
                    cnt <= 0; bit_idx <= 0;
                    if (rx_s2 == 1'b0) state <= S_START;
                end
                S_START: begin
                    if (cnt == HALF-1) begin
                        cnt <= 0;
                        state <= (rx_s2 == 1'b0) ? S_DATA : S_IDLE;
                    end else cnt <= cnt + 1;
                end
                S_DATA: begin
                    if (cnt == CPB-1) begin
                        cnt <= 0;
                        shreg <= {rx_s2, shreg[7:1]};
                        if (bit_idx == 3'd7) state <= S_STOP;
                        else bit_idx <= bit_idx + 1'b1;
                    end else cnt <= cnt + 1;
                end
                S_STOP: begin
                    if (cnt == CPB-1) begin
                        cnt <= 0;
                        data <= shreg;
                        valid <= 1'b1;
                        frame_err <= (rx_s2 != 1'b1);
                        state <= S_IDLE;
                    end else cnt <= cnt + 1;
                end
            endcase
        end
    end
endmodule