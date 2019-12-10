/*************************************
   FPGA Solomons's KEY

		Copyright (c) 2014,19 MiSTer-X
**************************************/
module FPGA_SOLOMON
(
	input				MCLK,		// 48.0MHz
	input				RESET,
	
	input	  [7:0]	INP0,
	input	  [7:0]	INP1,
	input	  [7:0]	INP2,

	input	  [7:0]	DSW0,
	input	  [7:0]	DSW1,
	
	input   [8:0]	PH,
	input   [8:0]	PV,
	
	output			PCLK,
	output [11:0]	POUT,

	output [15:0]	SND,

	input				ROMCL,
	input  [19:0]	ROMAD,
	input	  [7:0]	ROMDT,
	input				ROMEN
);

// Clock Generator
wire CLK24M, CLK12M, CLK6M, CLK4M, CLK3M, CLK1M5;
SOLOMON_CLKGEN cgen( MCLK, CLK24M, CLK12M, CLK6M, CLK4M, CLK3M, CLK1M5 );

wire VCLKx8  = MCLK;
wire VCLKx4  = CLK24M;
wire VCLKx2  = CLK12M;
wire VCLK    = CLK6M;

wire CPUCL   = CLK4M;
wire SCPUCL  = CLK3M;

// Main CPU
wire [15:0] CPUAD;
wire  [7:0] CPUWD,VIDDT;
wire			CPUMW,SNDWR,VIDDV,VBLK;
SOLOMON_MAIN main
(
	RESET,
	CPUCL, CPUAD, CPUWD, CPUMW,
	SNDWR,
	VIDDT, VIDDV, VBLK,
	INP0,INP1,INP2,DSW0,DSW1,

	ROMCL,ROMAD,ROMDT,ROMEN
);

// Video
wire SNDT;
SOLOMON_VIDEO video
(
	VCLKx4,VCLKx2,VCLK, 
	PH,PV,
	PCLK,POUT,
	VBLK,SNDT,

	CPUCL,CPUAD,CPUMW,CPUWD,
	VIDDT,VIDDV,

	ROMCL,ROMAD,ROMDT,ROMEN
);

// Sound
wire [7:0] SNDNO = CPUWD;
SOLOMON_SOUND sound
(
	RESET,SCPUCL,
	CPUCL,SNDNO,SNDWR,SNDT,
	CLK1M5,
	SND,

	ROMCL,ROMAD,ROMDT,ROMEN
);

endmodule


module SOLOMON_CLKGEN
(
	input			MCLK,

	output		CLK24M,
	output		CLK12M,
	output		CLK6M,
	output reg	CLK4M,
	output		CLK3M,
	output		CLK1M5
);

reg [4:0] CLKS;
always @( posedge MCLK ) CLKS <= CLKS+1;

assign CLK24M = CLKS[0];
assign CLK12M = CLKS[1];
assign CLK6M  = CLKS[2];
assign CLK3M  = CLKS[3];
assign CLK1M5 = CLKS[4];

reg [2:0] count;
always @( posedge MCLK ) begin
	if (count > 3'd5) begin
		count <= count - 3'd5;
		CLK4M <= ~CLK4M;
	end
	else count <= count + 3'd1;
end

endmodule

