//	Copyright (c) 2014,19 MiSTer-X

module SOLOMON_SOUND
(
	input				RESET,
	input				CPUCL,

	input				AXSCL,
	input  [7:0]	SNDNO,
	input				SNDWR,
	input				SNDT,

	input				PSGCL,

	output [15:0]	SNDO,
	
	input				DLCL,
	input  [19:0]	DLAD,
	input	  [7:0]	DLDT,
	input				DLEN
);

wire [15:0] CPUAD;
wire  [7:0] CPUID,CPUWD;
wire			CPUMR,CPUMW,CPUIW;
wire			CPUNMI,CPUIRQ;

wire  [7:0]	SNDLT,RAMDT,ROMDT;
wire			LATDV,RAMDV,ROMDV;

SSADEC adec(CPUAD,LATDV,RAMDV,ROMDV);
RAM800 wram(CPUCL,CPUAD[10:0],RAMDV & CPUMW,CPUWD,RAMDT);
SNDROM irom(CPUCL,CPUAD[13:0],ROMDT,DLCL,DLAD,DLDT,DLEN);
DSEL3D dsel(CPUID,CPUMR,LATDV,SNDLT,RAMDV,RAMDT,ROMDV,ROMDT);
INTCTR ictr(RESET,AXSCL,SNDNO,SNDWR,SNDT,CPUNMI,CPUIRQ,SNDLT);
Z80IP  scpu(RESET,CPUCL,CPUAD,CPUID,CPUWD,CPUMR,CPUMW,CPUNMI,CPUIRQ,CPUIW);
PSGx3  psgs(RESET,PSGCL,CPUCL,CPUAD[7:0],CPUIW,CPUWD,SNDO); 

endmodule


module SSADEC
(
	input	 [15:0]	CPUAD,

	output			LATDV,
	output			RAMDV,
	output			ROMDV
);

assign LATDV = (CPUAD==16'h8000);
assign RAMDV = (CPUAD[15:11]==5'b01000);
assign ROMDV = (CPUAD[15:14]==2'b00);

endmodule


module INTCTR
(
	input					RESET,
	input					AXSCL,
	input		  [7:0]	SNDNO,
	input					SNDWR,
	input					SNDT,

	output				NMI,
	output				IRQ,
	output reg [7:0]	SNDLT
);

reg [3:0] NMICN, IRQCN;
reg       pSNDW, pIRQQ;

assign 	 NMI = (NMICN!=0);
assign 	 IRQ = (IRQCN!=0);

always @( posedge AXSCL or posedge RESET ) begin
	if (RESET) begin
		SNDLT <= 0;
		NMICN <= 0;
		IRQCN <= 0;
		pSNDW <= 0;
		pIRQQ <= 0;
	end
	else begin
		pSNDW <= SNDWR;
		if ((pSNDW^SNDWR)&SNDWR) begin
			SNDLT <= SNDNO;
			NMICN <= 15;
		end
		else begin
			NMICN <= NMI ? (NMICN-1) : 0;
		end

		pIRQQ <= SNDT;
		if ((pIRQQ^SNDT)&SNDT) begin
			IRQCN <= 15;
		end
		else begin
			IRQCN <= IRQ ? (IRQCN-1) : 0;
		end
	end
end

endmodule


module PSGx3
(
	input			RESET,
	input			PSGCL,
	input			CL,
	input	[7:0]	AD,
	input			WR,
	input [7:0]	OD,

	output [15:0] SNDOUT
);

wire [7:0] A0,B0,C0;
wire [7:0] A1,B1,C1;
wire [7:0] A2,B2,C2;

wire rst  = ~RESET;
wire asel = ~AD[0];
wire wd   = ~WR;

wire cs_sg1 = ~(AD[7:4]==4'h1);
wire cs_sg2 = ~(AD[7:4]==4'h2);
wire cs_sg3 = ~(AD[7:4]==4'h3);

PSG sg1(rst,CL,PSGCL,asel,cs_sg1,wd,OD,A0,B0,C0);
PSG sg2(rst,CL,PSGCL,asel,cs_sg2,wd,OD,A1,B1,C1);
PSG sg3(rst,CL,PSGCL,asel,cs_sg3,wd,OD,A2,B2,C2);

wire [15:0] o = A0+B0+C0+A1+B1+C1+A2+B2+C2;
wire 			f = (o[15]|o[14]||o[13]|o[12]);
wire [11:0]	p = {12{f}}|o[11:0];

assign SNDOUT = {p,4'h0};

endmodule


module PSG
(
	input				rst_n,
	input				axsclk,

	input				clk,
	input				asel,
	input				cs_n,
	input				wr_n,
	input  [7:0]	ID,

	output reg [7:0]	A,
	output reg [7:0]	B,
	output reg [7:0]	C
);

wire [9:0] frd;
PSGFIFO ff (
	axsclk,~(cs_n|wr_n),{asel,1'b1,ID},
	~clk,frd
);

wire [7:0] Sx;
wire [1:0] Sc;
YM2149 psg (
	.I_DA(frd[7:0]),.I_A9_L(~frd[8]),.I_BDIR(frd[8]),.I_BC1(frd[9]),
	.I_A8(1'b1),.I_BC2(1'b1),.I_SEL_L(1'b1),
	.O_AUDIO(Sx),.O_CHAN(Sc),
	.ENA(1'b1),.RESET_L(rst_n),.CLK(clk)
);

always @(posedge clk) begin 
	case (Sc)
	2'd0: A <= Sx;
	2'd1: B <= Sx;
	2'd2: C <= Sx;
	default:;
	endcase
end

endmodule


module PSGFIFO
(
	input					WCL,
	input					WEN,
	input [9:0]			WDT,

	input					RCL,
	output reg [9:0]	RDT
);

reg [9:0] core [0:7];
reg [2:0] wp,rp;

always @(posedge WCL) begin
	if (WEN) begin
		core[wp] <= WDT;
		wp <= wp+1;
	end
end

always @(posedge RCL) begin
	if (wp!=rp) begin
		RDT <= core[rp];
		 rp <= rp+1;
	end
	else RDT <= 0;
end

endmodule
