module sha256_core (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [511:0] block,   // word 0 di bit [511:480]  
    input  wire [255:0] h_in,    // state awal (IV untuk hash baru)
    output reg          busy,
    output reg          done,    // pulsa 1 siklus
    output reg  [255:0] h_out
);
    localparam [2047:0] KALL = {
        32'h428a2f98,32'h71374491,32'hb5c0fbcf,32'he9b5dba5,32'h3956c25b,32'h59f111f1,32'h923f82a4,32'hab1c5ed5,
        32'hd807aa98,32'h12835b01,32'h243185be,32'h550c7dc3,32'h72be5d74,32'h80deb1fe,32'h9bdc06a7,32'hc19bf174,
        32'he49b69c1,32'hefbe4786,32'h0fc19dc6,32'h240ca1cc,32'h2de92c6f,32'h4a7484aa,32'h5cb0a9dc,32'h76f988da,
        32'h983e5152,32'ha831c66d,32'hb00327c8,32'hbf597fc7,32'hc6e00bf3,32'hd5a79147,32'h06ca6351,32'h14292967,
        32'h27b70a85,32'h2e1b2138,32'h4d2c6dfc,32'h53380d13,32'h650a7354,32'h766a0abb,32'h81c2c92e,32'h92722c85,
        32'ha2bfe8a1,32'ha81a664b,32'hc24b8b70,32'hc76c51a3,32'hd192e819,32'hd6990624,32'hf40e3585,32'h106aa070,
        32'h19a4c116,32'h1e376c08,32'h2748774c,32'h34b0bcb5,32'h391c0cb3,32'h4ed8aa4a,32'h5b9cca4f,32'h682e6ff3,
        32'h748f82ee,32'h78a5636f,32'h84c87814,32'h8cc70208,32'h90befffa,32'ha4506ceb,32'hbef9a3f7,32'hc67178f2
    };

    function [31:0] rotr(input [31:0] x, input integer n);
        rotr = (x >> n) | (x << (32 - n));
    endfunction
    function [31:0] SIG0(input [31:0] x); SIG0 = rotr(x,2)  ^ rotr(x,13) ^ rotr(x,22); endfunction
    function [31:0] SIG1(input [31:0] x); SIG1 = rotr(x,6)  ^ rotr(x,11) ^ rotr(x,25); endfunction
    function [31:0] sig0(input [31:0] x); sig0 = rotr(x,7)  ^ rotr(x,18) ^ (x >> 3);   endfunction
    function [31:0] sig1(input [31:0] x); sig1 = rotr(x,17) ^ rotr(x,19) ^ (x >> 10);  endfunction

    reg [31:0]  a, b, c, d, e, f, g, h;
    reg [31:0]  W [0:15];
    reg [6:0]   t;
    reg [511:0] blk;
    reg [255:0] hin;
    integer i;

    wire [31:0] w_new = (t < 16) ? blk[(4'd15 - t[3:0]) * 32 +: 32]
                                 : (sig1(W[14]) + W[9] + sig0(W[1]) + W[0]);
    wire [31:0] k_t   = KALL[(6'd63 - t[5:0]) * 32 +: 32];
    wire [31:0] T1    = h + SIG1(e) + ((e & f) ^ (~e & g)) + k_t + w_new;
    wire [31:0] T2    = SIG0(a) + ((a & b) ^ (a & c) ^ (b & c));

    always @(posedge clk) begin
        if (!rst_n) begin
            busy <= 1'b0; done <= 1'b0; t <= 7'd0; h_out <= 256'd0;
        end else begin
            done <= 1'b0;
            if (!busy) begin
                if (start) begin
                    blk  <= block;
                    hin  <= h_in;
                    {a,b,c,d,e,f,g,h} <= h_in;
                    t    <= 7'd0;
                    busy <= 1'b1;
                end
            end else begin
                for (i = 0; i < 15; i = i + 1) W[i] <= W[i+1];
                W[15] <= w_new;
                h <= g; g <= f; f <= e; e <= d + T1;
                d <= c; c <= b; b <= a; a <= T1 + T2;
                t <= t + 7'd1;
                if (t == 7'd63) begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    h_out <= { hin[255:224] + (T1 + T2), hin[223:192] + a,
                               hin[191:160] + b,         hin[159:128] + c,
                               hin[127:96]  + (d + T1),  hin[95:64]   + e,
                               hin[63:32]   + f,         hin[31:0]    + g };
                end
            end
        end
    end
endmodule
