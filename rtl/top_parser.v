module top_parser #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD     = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       uart_rx_pin,
    output wire       uart_tx_pin,
    output wire [3:0] led
);
    // ---------- UART ----------
    wire [7:0] rx_data;
    wire       rx_valid, rx_err;
    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) u_rx (
        .clk(clk), .rst_n(rst_n), .rx(uart_rx_pin),
        .data(rx_data), .valid(rx_valid), .frame_err(rx_err));

    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;
    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) u_tx (
        .clk(clk), .rst_n(rst_n), .data(tx_data), .start(tx_start),
        .tx(uart_tx_pin), .busy(tx_busy));

    
    wire         frame_done, format_err;
    wire [7:0]   ver_type, src_id, dst_id, len, pay0;
    wire [31:0]  counter;
    wire [127:0] tag;
    wire [255:0] payload;
    frame_parser #(.CLK_FREQ(CLK_FREQ), .TIMEOUT_MS(10)) u_fp (
        .clk(clk), .rst_n(rst_n), .byte_valid(rx_valid), .byte_data(rx_data),
        .frame_done(frame_done), .format_err(format_err),
        .ver_type(ver_type), .src_id(src_id), .dst_id(dst_id), .len(len),
        .counter(counter), .tag(tag), .pay0(pay0), .payload(payload));

    
    wire       ev_ok, ev_auth_fail, ev_replay;
    wire [7:0] info_len, info_ctr, info_pay0;
    auth_ctrl u_auth (
        .clk(clk), .rst_n(rst_n), .frame_done(frame_done),
        .ver_type(ver_type), .src_id(src_id), .dst_id(dst_id), .len(len),
        .counter(counter), .tag(tag), .payload(payload),
        .ev_ok(ev_ok), .ev_auth_fail(ev_auth_fail), .ev_replay(ev_replay),
        .info_len(info_len), .info_ctr(info_ctr), .info_pay0(info_pay0));

    
    localparam [1:0] R_IDLE = 2'd0, R_SEND = 2'd1, R_WAIT_BUSY = 2'd2, R_WAIT_DONE = 2'd3;
    reg [1:0]  r_state;
    reg [1:0]  r_cnt;
    reg [31:0] reply_sr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state <= R_IDLE; r_cnt <= 0; reply_sr <= 0;
            tx_data <= 0; tx_start <= 1'b0;
        end else begin
            tx_start <= 1'b0;
            case (r_state)
                R_IDLE: begin
                    if (ev_ok) begin
                        reply_sr <= {8'h4F, info_len, info_ctr, info_pay0};   // 'O'
                        r_cnt <= 0; r_state <= R_SEND;
                    end else if (ev_auth_fail) begin
                        reply_sr <= {8'h41, info_len, info_ctr, info_pay0};   // 'A'
                        r_cnt <= 0; r_state <= R_SEND;
                    end else if (ev_replay) begin
                        reply_sr <= {8'h52, info_len, info_ctr, info_pay0};   // 'R'
                        r_cnt <= 0; r_state <= R_SEND;
                    end else if (format_err) begin
                        reply_sr <= {8'h45, 24'h000000};                      // 'E'
                        r_cnt <= 0; r_state <= R_SEND;
                    end
                end
                R_SEND: begin
                    if (!tx_busy) begin
                        tx_data  <= reply_sr[31:24];
                        tx_start <= 1'b1;
                        r_state  <= R_WAIT_BUSY;
                    end
                end
                R_WAIT_BUSY: if (tx_busy) r_state <= R_WAIT_DONE;
                R_WAIT_DONE: begin
                    if (!tx_busy) begin
                        reply_sr <= {reply_sr[23:0], 8'h00};
                        if (r_cnt == 2'd3) r_state <= R_IDLE;
                        else begin r_cnt <= r_cnt + 2'd1; r_state <= R_SEND; end
                    end
                end
            endcase
        end
    end

    
    reg ok_led, auth_led, rep_led;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin ok_led <= 0; auth_led <= 0; rep_led <= 0; end
        else begin
            if (ev_ok)        ok_led   <= ~ok_led;     
            if (ev_auth_fail) auth_led <= ~auth_led;   
            if (ev_replay)    rep_led  <= ~rep_led;    
        end
    end

    reg [31:0] hb_cnt;
    reg        hb;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin hb_cnt <= 0; hb <= 1'b0; end
        else if (hb_cnt == CLK_FREQ/2 - 1) begin hb_cnt <= 0; hb <= ~hb; end
        else hb_cnt <= hb_cnt + 1;
    end

    
    assign led = ~{hb, rep_led, auth_led, ok_led};
endmodule
