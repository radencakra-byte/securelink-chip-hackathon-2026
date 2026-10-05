module uart_tx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD     = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data,
    input  wire       start,
    output reg        tx,
    output wire       busy
);
    localparam integer CPB = CLK_FREQ / BAUD;
    localparam [1:0] S_IDLE = 2'd0, S_START = 2'd1, S_DATA = 2'd2, S_STOP = 2'd3;

    reg [1:0]  state;
    reg [15:0] cnt;
    reg [2:0]  idx;
    reg [7:0]  shreg;

    assign busy = (state != S_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; cnt <= 0; idx <= 0; shreg <= 0; tx <= 1'b1;
        end else begin
            case (state)
                S_IDLE: begin
                    tx <= 1'b1;
                    if (start) begin shreg <= data; cnt <= 0; state <= S_START; end
                end
                S_START: begin
                    tx <= 1'b0;
                    if (cnt == CPB-1) begin cnt <= 0; idx <= 0; state <= S_DATA; end
                    else cnt <= cnt + 1;
                end
                S_DATA: begin
                    tx <= shreg[0];
                    if (cnt == CPB-1) begin
                        cnt <= 0;
                        shreg <= {1'b0, shreg[7:1]};
                        if (idx == 3'd7) state <= S_STOP;
                        else idx <= idx + 1'b1;
                    end else cnt <= cnt + 1;
                end
                S_STOP: begin
                    tx <= 1'b1;
                    if (cnt == CPB-1) begin cnt <= 0; state <= S_IDLE; end
                    else cnt <= cnt + 1;
                end
            endcase
        end
    end
endmodule