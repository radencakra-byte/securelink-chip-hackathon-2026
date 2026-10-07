module frame_parser #(
    parameter CLK_FREQ    = 50_000_000,
    parameter MAX_PAYLOAD = 32,
    parameter [7:0] SOF   = 8'hA5,
    parameter TIMEOUT_MS  = 10
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         byte_valid,
    input  wire [7:0]   byte_data,
    output reg          frame_done,    // pulsa 1 siklus: frame lengkap dan format valid
    output reg          format_err,    // pulsa 1 siklus: LEN salah atau timeout
    output reg  [7:0]   ver_type,
    output reg  [7:0]   src_id,
    output reg  [7:0]   dst_id,
    output reg  [7:0]   len,
    output reg  [31:0]  counter,
    output reg  [127:0] tag,
    output wire [7:0]   pay0,          // byte pertama payload
    output wire [MAX_PAYLOAD*8-1:0] payload   // semua payload, byte 0 di LSB
	 
);
    localparam integer TIMEOUT_CYCLES = (CLK_FREQ / 1000) * TIMEOUT_MS;

    localparam [3:0] S_SOF = 4'd0, S_VER = 4'd1, S_SRC = 4'd2, S_DST = 4'd3,
                     S_LEN = 4'd4, S_CTR = 4'd5, S_PAY = 4'd6, S_TAG = 4'd7;

    reg [3:0]  state;
    reg [5:0]  idx;
    reg [31:0] to_cnt;
    reg [MAX_PAYLOAD*8-1:0] payload_flat;

    assign pay0 = payload_flat[7:0];
	 assign payload = payload_flat;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_SOF; idx <= 0; to_cnt <= 0;
            frame_done <= 0; format_err <= 0;
            ver_type <= 0; src_id <= 0; dst_id <= 0; len <= 0;
            counter <= 0; tag <= 0; payload_flat <= 0;
        end else begin
            frame_done <= 1'b0;
            format_err <= 1'b0;

            // timeout antar-byte (hanya saat frame sedang diterima)
            if (byte_valid) begin
                to_cnt <= 0;
            end else if (state != S_SOF) begin
                if (to_cnt == TIMEOUT_CYCLES - 1) begin
                    format_err <= 1'b1;
                    state <= S_SOF;
                    to_cnt <= 0;
                end else begin
                    to_cnt <= to_cnt + 32'd1;
                end
            end

            if (byte_valid) begin
                case (state)
                    S_SOF: if (byte_data == SOF) state <= S_VER;   // selain SOF = noise, diabaikan
                    S_VER: begin ver_type <= byte_data; state <= S_SRC; end
                    S_SRC: begin src_id   <= byte_data; state <= S_DST; end
                    S_DST: begin dst_id   <= byte_data; state <= S_LEN; end
                    S_LEN: begin
                        len <= byte_data;
                        idx <= 0;
                        payload_flat <= 0;
                        if (byte_data > MAX_PAYLOAD) begin
                            format_err <= 1'b1;
                            state <= S_SOF;
                        end else begin
                            state <= S_CTR;
                        end
                    end
                    S_CTR: begin
                        counter <= {counter[23:0], byte_data};      // big-endian
                        if (idx == 6'd3) begin
                            idx <= 0;
                            state <= (len == 0) ? S_TAG : S_PAY;
                        end else idx <= idx + 6'd1;
                    end
                    S_PAY: begin
                        payload_flat[idx*8 +: 8] <= byte_data;
                        if (idx == len - 1) begin
                            idx <= 0;
                            state <= S_TAG;
                        end else idx <= idx + 6'd1;
                    end
                    S_TAG: begin
                        tag <= {tag[119:0], byte_data};
                        if (idx == 6'd15) begin
                            idx <= 0;
                            state <= S_SOF;
                            frame_done <= 1'b1;
                        end else idx <= idx + 6'd1;
                    end
                    default: state <= S_SOF;
                endcase
            end
        end
    end
endmodule
