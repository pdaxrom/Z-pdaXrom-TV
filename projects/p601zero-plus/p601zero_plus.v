module p601zero (
	input clk_ext,

	input btn_resetn,
	
	output [8:0] seg_led_h,
	output [8:0] seg_led_l,
	output [2:0] led_rgb,
	
	input			rxd,
	output			txd,
	input			ps2clk,
	input			ps2dat,

	output			mss,
	output			msck,
	output			mosi,
	input			miso,

	output [19:0] SRAM_ADDR,
	inout [15:0] SRAM_DATA,
	output			SRAM_CE,
	output			SRAM_OE,
	output			SRAM_WE,
	output			SRAM_UB,
	output			SRAM_LB,

/*	output			flash_mss,
	output			flash_msck,
	output			flash_mosi,
	input			flash_miso,
	
	inout [19:0] gpio,
 */
 
	output [5:0] 	tvout,
	output [1:0]	audio
);
	parameter OSC_CLOCK = 24000000;

	parameter CPU_CLOCK = 8000000;

	parameter CLK_DIV_PERIOD = (OSC_CLOCK / CPU_CLOCK) / 2;
	
	parameter LED_REFRESH_CLOCK = 50;
	
	parameter LED_DIV_PERIOD = (OSC_CLOCK / LED_REFRESH_CLOCK) / 2;

	wire sys_clk;
	wire color_clk;
	wire pixel_clk;
	
	reg [24:0] led_cnt;
	reg [1:0] led_anode;
	wire [7:0] seg_byte;
	
/*
	CPU related
 */

	reg sys_res = 1;
	wire sys_rw;	wire sys_vma;
	wire [15:0] AD;
	wire [7:0] DI;
	wire [7:0] DO;

	wire vpu_irq;
	wire simpleio_irq;
	wire uartio_irq;

	reg [3:0] sys_res_delay = 4'b1000;

	mcu_pll pll_impl(
		.CLKI(clk_ext),
		.CLKOP(sys_clk),
		.CLKOS(color_clk),
		.CLKOS2(pixel_clk)
	);

	always @ (posedge sys_clk)
	begin		if (sys_res) led_anode <= 2'b01;
		else begin
			if (led_cnt == (LED_DIV_PERIOD - 1)) begin
				led_anode <= ~led_anode;
				led_cnt <= 0;
			end else led_cnt <= led_cnt + 1'b1;
		end
	end

	always @ (posedge sys_clk or negedge btn_resetn)
	begin
		if (!btn_resetn) begin
			sys_res <= 1;
			sys_res_delay <= 4'b1000;
		end else begin
			if (sys_res_delay == 4'b0000) begin
				sys_res <= 0;
			end else sys_res_delay <= sys_res_delay - 4'b0001;
		end
	end

	assign seg_led_h[8] = led_anode[1];
	assign seg_led_l[8] = led_anode[0];

	wire [15:0] VADDR;
	wire vpu_vramcs;
	wire bram_disable;
	wire [7:0] bramd;
	wire [7:0] sramd;
	
	/*
		Mapping BRAM to $0000 - $0FFF
		mirroring    to $E800 - $F7FF
		to enable system start without
		external RAM.
	 */
	 
	wire [15:0] bram_ad = vpu_vramcs ? VADDR : AD;
	wire bram_0p  = bram_ad[15:12] == 4'b0000;
	wire bram_13p = bram_ad[15:11] == 5'b11101;
	wire bram_14p = bram_ad[15:11] == 5'b11110;
	
	wire en_bram = (bram_0p || bram_13p || bram_14p) && (!bram_disable);

	wire DS0 = (AD[15:5] == 11'b11100110000); // $E600
	wire DS1 = (AD[15:5] == 11'b11100110001); // $E620
	wire DS2 = (AD[15:5] == 11'b11100110010); // $E640
	wire DS3 = (AD[15:5] == 11'b11100110011); // $E660
	wire DS4 = (AD[15:5] == 11'b11100110100); // $E680
	wire DS5 = (AD[15:5] == 11'b11100110101); // $E6A0
	wire DS6 = (AD[15:5] == 11'b11100110110); // $E6C0
	wire DS7 = (AD[15:5] == 11'b11100110111); // $E6E0

	wire en_vpu = DS0; // $E600
	wire cs_vpu = en_vpu && sys_vma;
	wire [7:0] vpud;
	
	wire vpu_hold;

	vpu vpu_impl(
		.clk(sys_clk),
		.rst(sys_res),
		.irq(vpu_irq),
		.AD(AD[3:0]),
		.DI(DO),
		.DO(vpud),
		.rw(sys_rw),
		.cs(cs_vpu),
		.pixel_clk(pixel_clk),
		.color_clk(color_clk),
		
		.VADDR(VADDR),
		.VDATA(en_bram? bramd : sramd),
		.vramcs(vpu_vramcs),
		.hold(vpu_hold),
		.bus_ready(~sys_vma),
		
		.tvout(tvout)
	);

//	assign vpu_vramcs = 0;
//	assign vpu_hold = 0;

	wire en_simpleio = DS5 && (AD[4] == 1'b0); // $E6A0
	wire cs_simpleio = en_simpleio && sys_vma;
	wire [7:0] simpleiod;
	simpleio simpleio1 (
		.clk(sys_clk),
		.rst(sys_res),
		.irq(simpleio_irq),
		.AD(AD[3:0]),
		.DI(DO),
		.DO(simpleiod),
		.rw(sys_rw),
		.cs(cs_simpleio),
		.clk_in(sys_clk),
		.led7hi(seg_led_h[7:0]),
		.led7lo(seg_led_l[7:0]),
		.rgb1(led_rgb)
	);

	wire en_uartio = DS5 && (AD[4] == 1'b1); // $E6B0
	wire cs_uartio = en_uartio && sys_vma;
	wire [7:0] uartiod;
	uartio uartio1 (
		.clk(sys_clk),
		.rst(sys_res),
		.irq(uartio_irq),
		.AD(AD[2:0]),
		.DI(DO),
		.DO(uartiod),
		.rw(sys_rw),
		.cs(cs_uartio),
		.clk_in(sys_clk),
		.rxd(rxd),
		.txd(txd),
		.ps2clk(ps2clk),
		.ps2dat(ps2dat)
	);

	wire en_sdcardio = DS6; // $E6C0
	wire cs_sdcardio = en_sdcardio && sys_vma;
	wire [7:0] sdcardiod;

	sdcardio spi_impl(
		.clk(sys_clk),
		.rst(sys_res),
		.AD(AD[2:0]),
		.DI(DO),
		.DO(sdcardiod),
		.rw(sys_rw),
		.cs(cs_sdcardio),
		
		.clk_in(sys_clk),
		
		.mosi(mosi),
		.msck(msck),
		.miso(miso),
		.mss(mss)
	);

	wire en_pagesel = DS7; // $E6F0
	wire cs_pagesel = en_pagesel && sys_vma;
	wire [7:0] pageseld;
	wire [3:0] mempage;
	wire rampage_lock;
	wire sysboot_lock;
	wire brom_disable;
	pagesel pagesel_imp (
		.clk(sys_clk),
		.rst(sys_res),
		.AD(AD[0]),
		.DI(DO),
		.DO(pageseld),
		.rw(sys_rw),
		.cs(cs_pagesel),
		.page(mempage),
		.rampage_lock(rampage_lock),
		.sysboot_lock(sysboot_lock),
		.bram_disable(bram_disable),
		.brom_disable(brom_disable)
	);

	wire sysbooten = (AD[15:11] == 5'b11111);
	wire en_brom = sysbooten && (!brom_disable);
	wire cs_brom = en_brom && sys_vma;
	wire [7:0] bromd;
	mcu_rom brom (
		.OutClock(sys_clk),
		.Reset(sys_res),
		.OutClockEn(cs_brom),
		.Address(AD[10:0]),
		.Q(bromd)
	);

	wire int_vramcs = vpu_vramcs && en_bram;
	wire cs_bram = (en_bram && sys_vma) || int_vramcs;
	mcu_ram bram (
		.Clock(sys_clk),
		.ClockEn(cs_bram),
		.Reset(sys_res),
		.WE(int_vramcs ? 1'b0 : ((~sys_clk) & (~sys_rw))),
		.Address( {(bram_13p || bram_14p) ? ~bram_ad[11] : bram_ad[11], bram_ad[10:0]}),
		.Data(DO),
		.Q(bramd)
	);

	wire ext_vramcs = vpu_vramcs && (~en_bram);
	wire pageen = mempage[3] && (AD[15:13] == 3'b110);
	wire en_ext = (!(en_brom | en_bram | en_vpu | en_simpleio | en_uartio | en_sdcardio | en_pagesel)) & 
					(pageen ? (rampage_lock ? sys_rw : 1'b1) : 1'b1) &
					(sysbooten ? (sysboot_lock ? sys_rw : 1'b1) : 1'b1);

	wire [20:0] ram_addr = ext_vramcs ? {5'b00000, VADDR} :
						  pageen   ? {5'b00001, mempage[2:0], AD[12:0]} : {5'b00000, AD};
	wire cs_sram = (en_ext & sys_vma) | ext_vramcs;

/*
	sram16_to_8 sram8_impl(
		.Clock(sys_clk),
		.ClockEn(cs_sram),
		.WE(ext_vramcs ? 1'b0 : ((~sys_clk) & (~sys_rw))),
		.Address(ram_addr),
		.Data(DO),
		.Q(sramd),
		.ext_addr(SRAM_ADDR),
		.ext_dq(SRAM_DATA),
		.ext_ce_n(SRAM_CE),
		.ext_oe_n(SRAM_OE),
		.ext_we_n(SRAM_WE),
		.ext_lb_n(SRAM_LB),
		.ext_ub_n(SRAM_UB)
	);
*/

	wire cpu_clk = vpu_hold ? 1'b1 : sys_clk;

	assign SRAM_LB = ram_addr[0];
	assign SRAM_UB = ~ram_addr[0];

	assign SRAM_ADDR = ram_addr[20:1];
	assign SRAM_OE = ext_vramcs ? 1'b0 : ~(sys_rw);
	assign SRAM_WE = ext_vramcs ? 1'b1 :   (sys_rw);
	assign SRAM_CE = ~((en_ext & sys_vma & (sys_rw  | cpu_clk)) | ext_vramcs);
	assign SRAM_DATA[7:0]   = (ext_vramcs | sys_rw | (   ram_addr[0]))?8'bZ:DO;
	assign SRAM_DATA[15:8] = (ext_vramcs | sys_rw | (~ram_addr[0]))?8'bZ:DO;
	assign sramd = ram_addr[0]?SRAM_DATA[15:8]:SRAM_DATA[7:0];

		assign DI = en_ext      ? sramd:
				en_bram		? bramd:
				en_brom		? bromd:
				en_vpu		? vpud:
				en_simpleio	? simpleiod:
				en_uartio	? uartiod:
				en_sdcardio ? sdcardiod:
				en_pagesel  ? pageseld:
				8'b11111111;

//	reg [2:0] extbus_clkdiv_cnt;
//	reg dyn_clk;
//	always @ (posedge sys_clk_out) begin
//		if (extbus_clkdiv_cnt >= (((en_ext && sys_vma) || vpu_hold)?3'b001:3'b000)) begin
//			dyn_clk <= !dyn_clk;
//			extbus_clkdiv_cnt <= 0;
//		end else extbus_clkdiv_cnt <= extbus_clkdiv_cnt + 1'b1;
//	end

//	assign sys_clk = dyn_clk;
//	assign sys_clk = sys_clk_out;

//	wire cpu_clk = vpu_hold ? 1'b1 : sys_clk;
/*	
	cpu68 mc6801 (
		.clk(cpu_clk),
		.rst(sys_res),
		.irq(cpu_irq),
		.nmi(1'b0),
		.hold(1'b0),
		.halt(1'b0),
		.rw(sys_rw),
		.vma(sys_vma),
		.address(AD),
		.data_in(DI),
		.data_out(DO)
	);
 */
 
	wire cpu_irq = simpleio_irq | uartio_irq | vpu_irq;
	cpu11 cpu11impl(
		.clk(cpu_clk),
		.rst(sys_res),
		.rw(sys_rw),
		.vma(sys_vma),
		.address(AD),
		.data_in(DI),
		.data_out(DO),
		.irq(cpu_irq),
		.xirq(1'b0),
		.irq_ext3(1'b0),
		.irq_ext2(1'b0),
		.irq_ext1(1'b0),
		.irq_ext0(1'b0)
	);

endmodule
