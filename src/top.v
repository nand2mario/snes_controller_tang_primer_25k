
// see snescontroller.v

module snes_controller_top (
    input sys_clk,
    input s1,

    output UART_TXD,
    output [1:0] led,

    output joy1_latch,
    output joy1_clk,
    input joy1_data,
    output joy2_latch,
    output joy2_clk,
    input joy2_data
);

wire mclk;                      // SNES master clock at 21.5054Mhz (~21.477)

gowin_pll_snes pll_snes (
    .clkout0(mclk),
    .clkout1(),
    .clkout2(),
    .clkin(sys_clk)             // 50 Mhz input
);

localparam FREQ = 21500000;
localparam TIME_6US = FREQ / 1000000 * 6;

reg [$clog2(FREQ)-1:0] cnt;
reg [2:0] state;
wire [15:0] btns1;
wire [15:0] btns2;

snescontroller cntr1 (
    .clk(mclk), .resetn(1), .buttons(btns1),
    .joy_strb(joy1_latch), .joy_clk(joy1_clk), .joy_data(joy1_data)
);

snescontroller cntr2 (
    .clk(mclk), .resetn(1), .buttons(btns2),
    .joy_strb(joy2_latch), .joy_clk(joy2_clk), .joy_data(joy2_data)
);

`include "print.v"
defparam tx.uart_freq=115200;
defparam tx.clk_freq=FREQ;
assign print_clk = mclk;
assign UART_TXD = uart_txp;

always @(posedge mclk) begin
    cnt <= cnt + 1;

    case (state)
    3'd0: if (cnt == FREQ / 10) begin
        `print("Press S1\n", STR);
        state <= 1;
    end
    
    3'd1: /*if (s1)*/ begin
        cnt <= 0;
        state <= 2;
    end

    3'd2: begin         // print result
        case (cnt[19:0])
        20'h00000: `print("\x0dJOY1: ", STR);
        20'h10000: if (!btns1[15]) `print("B ", STR);
                   else           `print("_ ", STR);
        20'h18000: if (!btns1[14]) `print("Y ", STR);
                   else           `print("_ ", STR);
        20'h20000: if (!btns1[13]) `print("SEL ", STR);
                   else           `print("___ ", STR);
        20'h28000: if (!btns1[12]) `print("STA ", STR);
                   else           `print("___ ", STR);
        20'h30000: if (!btns1[11]) `print("UP ", STR);
                   else           `print("__ ", STR);
        20'h38000: if (!btns1[10]) `print("DN ", STR);
                   else           `print("__ ", STR);
        20'h40000: if (!btns1[9])  `print("LE ", STR);
                   else           `print("__ ", STR);
        20'h48000: if (!btns1[8])  `print("RI ", STR);
                   else           `print("__ ", STR);
        20'h50000: if (!btns1[7])  `print("A ", STR);
                   else           `print("_ ", STR);
        20'h58000: if (!btns1[6])  `print("X ", STR);
                   else           `print("_ ", STR);
        20'h60000: if (!btns1[5])  `print("L ", STR);
                   else           `print("_ ", STR);
        20'h68000: if (!btns1[4])  `print("R ", STR);
                   else           `print("_ ", STR);

        20'h70000: `print("  JOY2: ", STR);
        20'h80000: if (!btns2[15]) `print("B ", STR);
                   else           `print("_ ", STR);
        20'h88000: if (!btns2[14]) `print("Y ", STR);
                   else           `print("_ ", STR);
        20'h90000: if (!btns2[13]) `print("SEL ", STR);
                   else           `print("___ ", STR);
        20'h98000: if (!btns2[12]) `print("STA ", STR);
                   else           `print("___ ", STR);
        20'hA0000: if (!btns2[11]) `print("UP ", STR);
                   else           `print("__ ", STR);
        20'hA8000: if (!btns2[10]) `print("DN ", STR);
                   else           `print("__ ", STR);
        20'hB0000: if (!btns2[9])  `print("LE ", STR);
                   else           `print("__ ", STR);
        20'hB8000: if (!btns2[8])  `print("RI ", STR);
                   else           `print("__ ", STR);
        20'hC0000: if (!btns2[7])  `print("A ", STR);
                   else           `print("_ ", STR);
        20'hC8000: if (!btns2[6])  `print("X ", STR);
                   else           `print("_ ", STR);
        20'hD0000: if (!btns2[5])  `print("L ", STR);
                   else           `print("_ ", STR);
        20'hD8000: if (!btns2[4])  `print("R ", STR);
                   else           `print("_ ", STR);
        20'hF0000: begin
            cnt <= 0;
            state <= 3;
        end
        default: ;
        endcase
    end

    3'd3: begin         // wait 16ms, then start again
        if (cnt == FREQ / 1000 * 16) begin
            cnt <= 0;
            state <= 2;
        end
    end

    endcase

end

assign led = cnt[19:18];

endmodule