`timescale 1ns/1ps
module tb_sha256;
    reg          clk = 0, rst_n = 0, start = 0;
    reg  [511:0] block;
    reg  [255:0] h_in;
    wire         busy, done;
    wire [255:0] h_out;

    sha256_core dut (.clk(clk), .rst_n(rst_n), .start(start),
                     .block(block), .h_in(h_in),
                     .busy(busy), .done(done), .h_out(h_out));

    always #10 clk = ~clk;   // 50 MHz

    localparam [255:0] IV = {32'h6a09e667,32'hbb67ae85,32'h3c6ef372,32'ha54ff53a,
                             32'h510e527f,32'h9b05688c,32'h1f83d9ab,32'h5be0cd19};
    localparam [255:0] EXPECT = {32'hba7816bf,32'h8f01cfea,32'h414140de,32'h5dae2223,
                                 32'hb00361a3,32'h96177a9c,32'hb410ff61,32'hf20015ad};

    initial begin
        $dumpfile("sha.vcd"); $dumpvars(0, tb_sha256);
        block = {32'h61626380, 448'd0, 32'h00000018};   // "abc" + padding, panjang 24 bit
        h_in  = IV;
        repeat (4) @(posedge clk);
        rst_n <= 1;
        repeat (2) @(posedge clk);
        start <= 1; @(posedge clk); start <= 0;
        wait (done); #1;
        if (h_out === EXPECT) $display("PASS: SHA-256(abc) benar");
        else                  $display("FAIL: dapat %h", h_out);
        $finish;
    end
endmodule