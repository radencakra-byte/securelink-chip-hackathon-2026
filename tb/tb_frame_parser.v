`timescale 1ns/1ps
module tb_frame_parser;
    reg clk = 0, rst_n = 0, byte_valid = 0;
    reg [7:0] byte_data = 0;
    wire frame_done, format_err;
    wire [7:0] ver_type, src_id, dst_id, len, pay0;
    wire [31:0] counter;
    wire [127:0] tag;

    frame_parser #(.CLK_FREQ(50_000_000), .TIMEOUT_MS(1)) dut (
        .clk(clk), .rst_n(rst_n), .byte_valid(byte_valid), .byte_data(byte_data),
        .frame_done(frame_done), .format_err(format_err),
        .ver_type(ver_type), .src_id(src_id), .dst_id(dst_id), .len(len),
        .counter(counter), .tag(tag), .pay0(pay0));

    always #10 clk = ~clk;   // 50 MHz

    integer ok_cnt = 0, err_cnt = 0;
    always @(posedge clk) begin
        if (frame_done) ok_cnt  <= ok_cnt + 1;
        if (format_err) err_cnt <= err_cnt + 1;
    end

    task send_byte(input [7:0] b);
        begin
            @(posedge clk); byte_data <= b; byte_valid <= 1'b1;
            @(posedge clk); byte_valid <= 1'b0;
            repeat (20) @(posedge clk);
        end
    endtask

    task send_frame(input [7:0] plen);
        integer i;
        begin
            send_byte(8'hA5); send_byte(8'h01); send_byte(8'h11); send_byte(8'h22);
            send_byte(plen);
            send_byte(8'h00); send_byte(8'h00); send_byte(8'h00); send_byte(8'h07);
            for (i = 0; i < plen; i = i + 1) send_byte(8'h10 + i);
            for (i = 0; i < 16; i = i + 1)   send_byte(8'hB0 + i);
        end
    endtask

    initial begin
        #100 rst_n = 1; #100;

        send_frame(8'd4); #200;
        if (ok_cnt==1 && err_cnt==0 && len==4 && counter==32'd7 && src_id==8'h11 &&
            dst_id==8'h22 && pay0==8'h10 &&
            tag==128'hB0B1B2B3B4B5B6B7B8B9BABBBCBDBEBF)
            $display("PASS 1: frame valid LEN=4");
        else $display("FAIL 1: ok=%0d err=%0d len=%0d ctr=%0d", ok_cnt, err_cnt, len, counter);

        send_frame(8'd0); #200;
        if (ok_cnt==2 && err_cnt==0 && len==0 && pay0==8'h00) $display("PASS 2: frame valid LEN=0");
        else $display("FAIL 2: ok=%0d err=%0d", ok_cnt, err_cnt);

        send_byte(8'h00); send_byte(8'hFF); send_byte(8'h12);   // noise
        send_frame(8'd32); #200;
        if (ok_cnt==3 && err_cnt==0 && len==32) $display("PASS 3: noise diabaikan, LEN=32");
        else $display("FAIL 3: ok=%0d err=%0d", ok_cnt, err_cnt);

        send_byte(8'hA5); send_byte(8'h01); send_byte(8'h11); send_byte(8'h22); send_byte(8'd33); #200;
        if (ok_cnt==3 && err_cnt==1) $display("PASS 4: LEN=33 ditolak");
        else $display("FAIL 4: ok=%0d err=%0d", ok_cnt, err_cnt);

        send_byte(8'hA5); send_byte(8'h01); send_byte(8'h11);
        #1_500_000;
        if (ok_cnt==3 && err_cnt==2) $display("PASS 5: frame terpotong, timeout");
        else $display("FAIL 5: ok=%0d err=%0d", ok_cnt, err_cnt);

        send_frame(8'd4); #200;
        if (ok_cnt==4 && err_cnt==2) $display("PASS 6: parser pulih setelah error");
        else $display("FAIL 6: ok=%0d err=%0d", ok_cnt, err_cnt);

        $finish;
    end
endmodule