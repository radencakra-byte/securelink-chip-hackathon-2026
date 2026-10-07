`timescale 1ns/1ps
module tb_hmac;
    reg          clk = 0, rst_n = 0, start = 0;
    reg  [255:0] key;
    reg  [319:0] msg;
    reg  [5:0]   msg_len;
    wire         busy, done;
    wire [255:0] tag;

    hmac_ctrl dut (.clk(clk), .rst_n(rst_n), .start(start),
                   .key(key), .msg(msg), .msg_len(msg_len),
                   .busy(busy), .done(done), .tag(tag));

    always #10 clk = ~clk;   // 50 MHz

    localparam [255:0] EXPECT = {32'hb0344c61,32'hd8db3853,32'h5ca8afce,32'haf0bf12b,
                                 32'h881dc200,32'hc9833da7,32'h26e9376c,32'h2e32cff7};
    integer cyc;

    initial begin
        $dumpfile("hmac.vcd"); $dumpvars(0, tb_hmac);
        key     = {{20{8'h0b}}, 96'd0};
        msg     = {64'h4869205468657265, 256'd0};   // "Hi There"
        msg_len = 6'd8;
        repeat (4) @(posedge clk);
        rst_n <= 1;
        repeat (2) @(posedge clk);
        start <= 1; @(posedge clk); start <= 0;
        cyc = 0;
        while (!done) begin @(posedge clk); cyc = cyc + 1; end
        #1;
        if (tag === EXPECT) $display("PASS: HMAC-SHA256 RFC4231 TC1 benar (%0d siklus)", cyc);
        else                $display("FAIL: dapat %h", tag);
        $finish;
    end
endmodule