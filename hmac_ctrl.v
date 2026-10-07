module hmac_ctrl (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [255:0] key,       
    input  wire [319:0] msg,       
    input  wire [5:0]   msg_len,   
    output reg          busy,
    output reg          done,      
    output reg  [255:0] tag        
);
    localparam [255:0] IV = {32'h6a09e667,32'hbb67ae85,32'h3c6ef372,32'ha54ff53a,
                             32'h510e527f,32'h9b05688c,32'h1f83d9ab,32'h5be0cd19};

    /
    reg [255:0] key_r;
    reg [319:0] msg_r;
    reg [5:0]   len_r;

    
    wire [511:0] msg_pad = {msg_r, 192'd0};
    wire [15:0]  bitlen  = 16'd512 + {7'd0, len_r, 3'b000};   // (64 + len) * 8
    reg  [511:0] blk_msg;
    integer i;
    always @* begin
        for (i = 0; i < 64; i = i + 1) begin
            if (i < len_r)        blk_msg[511 - 8*i -: 8] = msg_pad[511 - 8*i -: 8];
            else if (i == len_r)  blk_msg[511 - 8*i -: 8] = 8'h80;
            else if (i == 62)     blk_msg[511 - 8*i -: 8] = bitlen[15:8];
            else if (i == 63)     blk_msg[511 - 8*i -: 8] = bitlen[7:0];
            else                  blk_msg[511 - 8*i -: 8] = 8'h00;
        end
    end

    // inti SHA-256
    reg          core_start;
    reg  [511:0] core_block;
    reg  [255:0] core_hin;
    wire         core_busy, core_done;
    wire [255:0] core_hout;

    sha256_core u_core (
        .clk(clk), .rst_n(rst_n), .start(core_start),
        .block(core_block), .h_in(core_hin),
        .busy(core_busy), .done(core_done), .h_out(core_hout)
    );

    localparam [2:0] IDLE = 3'd0, WI1 = 3'd1, WI2 = 3'd2, WO1 = 3'd3, WO2 = 3'd4;
    reg [2:0]   st;
    reg [255:0] inner_d;

    always @(posedge clk) begin
        if (!rst_n) begin
            st <= IDLE; busy <= 1'b0; done <= 1'b0; tag <= 256'd0;
            core_start <= 1'b0; core_block <= 512'd0; core_hin <= 256'd0;
            key_r <= 256'd0; msg_r <= 320'd0; len_r <= 6'd0; inner_d <= 256'd0;
        end else begin
            core_start <= 1'b0;
            done       <= 1'b0;
            case (st)
                IDLE: if (start) begin
                    key_r <= key; msg_r <= msg; len_r <= msg_len;
                    busy  <= 1'b1;
                    // 1) hash dalam, blok ipad
                    core_block <= {key, 256'd0} ^ {64{8'h36}};
                    core_hin   <= IV;
                    core_start <= 1'b1;
                    st <= WI1;
                end
                WI1: if (core_done) begin
                    // 2) hash dalam, blok pesan
                    core_block <= blk_msg;
                    core_hin   <= core_hout;
                    core_start <= 1'b1;
                    st <= WI2;
                end
                WI2: if (core_done) begin
                    inner_d <= core_hout;
                    // 3) hash luar, blok opad
                    core_block <= {key_r, 256'd0} ^ {64{8'h5c}};
                    core_hin   <= IV;
                    core_start <= 1'b1;
                    st <= WO1;
                end
                WO1: if (core_done) begin
                    // 4) hash luar, blok digest dalam (panjang 96 byte = 768 bit)
                    core_block <= {inner_d, 8'h80, 184'd0, 64'd768};
                    core_hin   <= core_hout;
                    core_start <= 1'b1;
                    st <= WO2;
                end
                WO2: if (core_done) begin
                    tag  <= core_hout;
                    busy <= 1'b0;
                    done <= 1'b1;
                    st   <= IDLE;
                end
                default: st <= IDLE;
            endcase
        end
    end
endmodule
