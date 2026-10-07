module auth_ctrl #(
    parameter [255:0] KEY = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         frame_done,
    input  wire [7:0]   ver_type,
    input  wire [7:0]   src_id,
    input  wire [7:0]   dst_id,
    input  wire [7:0]   len,
    input  wire [31:0]  counter,
    input  wire [127:0] tag,
    input  wire [255:0] payload,
    output reg          ev_ok,
    output reg          ev_auth_fail,
    output reg          ev_replay,
    output reg  [7:0]   info_len,
    output reg  [7:0]   info_ctr,
    output reg  [7:0]   info_pay0
);
    
    reg [319:0] msg_c;
    integer j;
    always @* begin
        msg_c = 320'd0;
        msg_c[319:312] = ver_type;
        msg_c[311:304] = src_id;
        msg_c[303:296] = dst_id;
        msg_c[295:288] = len;
        msg_c[287:256] = counter;
        for (j = 0; j < 32; j = j + 1)
            msg_c[255 - 8*j -: 8] = payload[8*j +: 8];
    end
    wire [5:0] msg_len_c = len[5:0] + 6'd8;   // 8 byte header + payload

    reg          hmac_start;
    wire         hmac_busy, hmac_done;
    wire [255:0] hmac_tag;

    hmac_ctrl u_hmac (
        .clk(clk), .rst_n(rst_n), .start(hmac_start),
        .key(KEY), .msg(msg_c), .msg_len(msg_len_c),
        .busy(hmac_busy), .done(hmac_done), .tag(hmac_tag)
    );

    reg          waiting, have_last;
    reg [31:0]   ctr_r, last_ctr;
    reg [127:0]  rx_tag_r;
    reg [7:0]    len_r, pay0_r;

    always @(posedge clk) begin
        if (!rst_n) begin
            waiting <= 1'b0; have_last <= 1'b0; hmac_start <= 1'b0;
            ctr_r <= 0; last_ctr <= 0; rx_tag_r <= 0; len_r <= 0; pay0_r <= 0;
            ev_ok <= 0; ev_auth_fail <= 0; ev_replay <= 0;
            info_len <= 0; info_ctr <= 0; info_pay0 <= 0;
        end else begin
            ev_ok <= 1'b0; ev_auth_fail <= 1'b0; ev_replay <= 1'b0;
            hmac_start <= 1'b0;

            if (frame_done && !waiting) begin
                ctr_r <= counter; rx_tag_r <= tag;
                len_r <= len;     pay0_r <= payload[7:0];
                hmac_start <= 1'b1;
                waiting    <= 1'b1;
            end

            if (hmac_done && waiting) begin
                waiting   <= 1'b0;
                info_len  <= len_r;
                info_ctr  <= ctr_r[7:0];
                info_pay0 <= pay0_r;
                if (hmac_tag[255:128] != rx_tag_r)
                    ev_auth_fail <= 1'b1;                       // tag salah
                else if (have_last && (ctr_r <= last_ctr))
                    ev_replay <= 1'b1;                          // counter lama
                else begin
                    ev_ok     <= 1'b1;
                    last_ctr  <= ctr_r;
                    have_last <= 1'b1;
                end
            end
        end
    end
endmodule
