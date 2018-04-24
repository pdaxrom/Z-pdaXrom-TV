module rgb (
	input clk_in,
	input btn_reset,
	output [8:0] seg_led_h,
	output [8:0] seg_led_l,
	output led_r,
	output led_g,
	output led_b
);
	reg [7:0] x;
	
	parameter CLK_DIV_PERIOD = 6000000;
	
	reg [24:0] cnt;
	reg clk_div = 0;
	
	reg led_pow_h = 0;
	reg led_pow_l = 1;
	
	initial begin
		x = 0;
		cnt = 0;
	end

	always @ (posedge clk_in)
	begin
		if (cnt == (CLK_DIV_PERIOD - 1)) cnt <= 0;
		else cnt <= cnt + 1'b1;
		if (cnt < (CLK_DIV_PERIOD>>1)) clk_div <= 0;
		else clk_div <= 1'b1;
			
		if ((cnt % (CLK_DIV_PERIOD / 64)) == 0)
		begin
			led_pow_h <= !led_pow_h;
			led_pow_l <= !led_pow_l;
		end
	end

	always @ (posedge clk_div or negedge btn_reset)
	begin
		if (!btn_reset) x <= 0;
		else	x <= x + 1'b1;
	end

	assign seg_led_h[8] = led_pow_h;
	assign seg_led_l[8] = led_pow_l;

	assign seg_led_h[7] = 1;
	assign seg_led_l[7] = 1;

	segled segled_h( .x (x[7:4]),
			.z (seg_led_h[6:0])
			);

	segled segled_l( .x (x[3:0]),
			.z (seg_led_l[6:0])
			);

	assign led_r = (x[1:0] == 2'b01)?0:1;
	assign led_g =  (x[1:0] == 2'b10)?0:1;
	assign led_b =  (x[1:0] == 2'b11)?0:1;

endmodule
