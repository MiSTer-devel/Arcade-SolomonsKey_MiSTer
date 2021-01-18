//	Copyright (c) 2014,19 MiSTer-X

module SOLOMON_MAIN
(
	input				RESET,

	input				CPUCL,
	output [15:0]	CPUAD,
	output  [7:0]	CPUWD,
	output			CPUMW,
	output			SNDWR,

	input   [7:0]	VIDDT,
	input				VIDDV,
	input				VBLK,

	input	  [7:0]	INP0,
	input	  [7:0]	INP1,
	input	  [7:0]	INP2,

	input	  [7:0]	DSW0,
	input	  [7:0]	DSW1,
	
	input				DLCL,
	input  [19:0]	DLAD,
	input	  [7:0]	DLDT,
	input				DLEN
);

wire		  CPUMR,ROMDV,RAMDV,INPDV,NMIWR,NMI,CREDIT;
wire [7:0] CPUID,ROMDT,RAMDT,INPDT,PRODT;

SMADEC adec(CPUAD,CPUMW,RAMDV,INPDV,NMIWR,SNDWR);
DSEL4D dsel(CPUID,CPUMR,ROMDV,ROMDT,RAMDV,RAMDT,VIDDV,VIDDT,INPDV,INPDT);
Z80IP  mcpu(RESET,CPUCL,CPUAD,CPUID,CPUWD,CPUMR,CPUMW,NMI,1'b0);
SMNMIC nmic(RESET,CPUCL,NMIWR,CPUWD[0],VBLK,INP2[2],NMI,CREDIT);
MAINROM rom(CPUCL,CPUAD,ROMDT,ROMDV,DLCL,DLAD,DLDT,DLEN);
RAM1000 ram(CPUCL,CPUAD[11:0],RAMDV & CPUMW,CPUWD,RAMDT);
PROTECT pro(RESET,CPUCL,CPUAD,CPUMW,CPUWD,PRODT);
HIDDSW  inp(INP0,INP1,INP2,DSW0,DSW1,CREDIT,PRODT,CPUAD[2:0],INPDT);

endmodule


module SMADEC
(
	input	[15:0] CPUAD,
	input			 CPUMW,

	output		 RAMDV,
	output		 INPDV,

	output		 NMIWR,
	output		 SNDWR
);

assign RAMDV = (CPUAD[15:12]==4'b1100);					// $C000-$CFFF
assign INPDV = (CPUAD[15:3]==13'b1110_0110_0000_0);	// $E600-$E607(RD)

assign NMIWR = (CPUAD==16'hE600) & CPUMW;					// $E600(WR)
assign SNDWR = (CPUAD==16'hE800) & CPUMW;					// $E800(WR)

endmodule


module SMNMIC
(
	input		RESET,
	input		ACL,
	input		NMIWR,
	input		MSKDT,
	input		VBLK,
	input		iCOIN,

	output 	NMI,
	output 	CREDIT
);

wire		 COIN = ~iCOIN;

reg		 pVBLK, pCOIN;
reg [3:0] fNMI;
reg [1:0] fCRE;
wire      bNMI = (fNMI!=0);
wire		 bCRE = (fCRE==0);
always @( posedge ACL or posedge RESET ) begin
	if (RESET) begin
		pVBLK <= VBLK;
		pCOIN <= COIN;
		fNMI  <= 0;
		fCRE  <= 0;
	end
	else begin
		pVBLK <= VBLK;
		if ((VBLK^pVBLK)&VBLK) begin
			pCOIN <= COIN;
			fCRE  <= ((COIN^pCOIN)&COIN) ? 3 : bCRE ? 0 : (fCRE-1);
			fNMI  <= 15;
		end
		else begin
			fNMI  <= bNMI ? (fNMI-1) : 0;
		end
	end
end

reg NMIMASK;
always @( posedge ACL or posedge RESET ) begin
	if (RESET) NMIMASK <= 0;
	else if (NMIWR) NMIMASK <= MSKDT;
end

assign NMI    = bNMI & NMIMASK;
assign CREDIT = bCRE;

endmodule


module HIDDSW
(
	input	 [7:0] INP0,
	input	 [7:0] INP1,
	input	 [7:0] INP2,

	input	 [7:0] DSW0,
	input	 [7:0] DSW1,

	input			 CRED,
	input	 [7:0] PROD,

	input  [2:0] AD,
	output [7:0] DT
);

wire [7:0] INPS  = {5'b11111,CRED,INP2[1:0]};

assign     DT	  = (AD==3'h0) ? ~INP0 :
						 (AD==3'h1) ? ~INP1 :
						 (AD==3'h2) ? ~INPS :
						 (AD==3'h3) ?  PROD :
						 (AD==3'h4) ?  DSW0 :
						 (AD==3'h5) ?  DSW1 :
										   8'h0 ;
endmodule


module PROTECT
(
	input				RESET,
	input				CPUCL,
	input [15:0]	CPUAD,
	input				CPUMW,
	input	 [7:0]	CPUWD,
	
	output reg [7:0] OUT
);

always @(posedge CPUCL or posedge RESET) begin
	if (RESET) OUT <= 0;
	else begin
		if ((CPUAD==16'hE803) & CPUMW) OUT <= (CPUWD & 8'h08);
	end
end

endmodule

