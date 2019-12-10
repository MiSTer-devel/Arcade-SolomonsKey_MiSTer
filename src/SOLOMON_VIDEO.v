//	Copyright (c) 2014,19 MiSTer-X

module SOLOMON_VIDEO
(
	input					VCLKx4,
	input					VCLKx2,
	input					VCLK,

	input 	[8:0]		PHi,
	input		[8:0]		PVi,

	output				PCLK,
	output  [11:0]		POUT,
	output				VBLK,
	output				SNDT,

	input					CL,
	input   [15:0]		AD,
	input					WR,
	input	   [7:0]		ID,
	output   [7:0]		OD,
	output				DV,
	
	input					DLCL,
	input  [19:0]		DLAD,
	input	  [7:0]		DLDT,
	input					DLEN
);

wire [8:0] PH,PV;
TGEN tgen(PHi,PVi,PH,PV,VBLK,SNDT);

wire  [7:0]	PALAD;
wire [11:0]	PALDT;
wire  [9:0]	FGVAD,BGVAD;
wire [15:0]	FGVDT,BGVDT;
wire 	[6:0]	SPAAD;
wire 	[7:0]	SPADT;
VRAMS vram
(
	VCLKx4,

	PALAD,PALDT,
	FGVAD,FGVDT,
	BGVAD,BGVDT,
	SPAAD,SPADT,

	CL,AD,WR,ID,
	OD,DV
);

wire [6:0] FGOUT, BGOUT, SPOUT;
FG fg( VCLKx2, VCLK, PH, PV, FGVAD, FGVDT, FGOUT, DLCL,DLAD,DLDT,DLEN );
BG bg( VCLKx2, VCLK, PH, PV, BGVAD, BGVDT, BGOUT, DLCL,DLAD,DLDT,DLEN );
SP sp( VCLKx4, VCLK, PH, PV, SPAAD, SPADT, SPOUT, DLCL,DLAD,DLDT,DLEN );

PMIX pmix( FGOUT, BGOUT, SPOUT, PALAD );

assign PCLK = VCLK;
assign POUT = PALDT;

endmodule


module PMIX
(
	input	 [6:0]	FGOUT,
	input	 [6:0]	BGOUT,
	input	 [6:0]	SPOUT,

	output [7:0]	PALAD
);

wire   FGOPQ = (FGOUT[3:0]!=0);
wire	 SPOPQ = (SPOUT[3:0]!=0);

assign PALAD = SPOPQ ? {1'b0,SPOUT} :
					FGOPQ ? {1'b0,FGOUT} :
							  {1'b1,BGOUT} ;
endmodule


module TGEN
(
	input	 [8:0]	PHi,
	input  [8:0]	PVi,

	output [8:0]	PH,
	output [8:0]	PV,
	output			VBLK,
	output			SNDT
);

assign PH   = PHi+1;
assign PV   = PVi+16;
assign VBLK = (PVi==224);
assign SNDT = (VBLK|(PVi==112))&(PHi<32);

endmodule


module VRAMS
(
	input				VCLKx4,

	input	  [7:0]	PALAD,
	output [11:0]	PALDT,

	input	  [9:0]	FGVAD,
	output [15:0]	FGVDT,

	input	  [9:0]	BGVAD,
	output [15:0]	BGVDT,

	input	  [6:0]	SPAAD,
	output  [7:0]	SPADT,
	
	input				CL,
	input  [15:0]	AD,
	input				WR,
	input	  [7:0]	ID,
	output  [7:0]	OD,
	output			DV
);

wire ACL  = CL;
wire VCL  = ~VCLKx4;

wire CSFG = (AD[15:11]==5'b1101_0);			// $D000-$D7FF
wire CSBG = (AD[15:11]==5'b1101_1);			// $D800-$DFFF
wire CSSA = (AD[15: 7]==9'b1110_0000_0);	// $E000-$E07F
wire CSPL = (AD[15: 9]==7'b1110_010);		// $E400-$E5FF

wire [7:0] DTFG, DTBG, DTSA, DTPL;
VDPRAM400x2 fg( ACL, AD[10:0], CSFG & WR, ID, DTFG, VCL, FGVAD, FGVDT );
VDPRAM400x2 bg( ACL, AD[10:0], CSBG & WR, ID, DTBG, VCL, BGVAD, BGVDT );
VDPRAM80		sa( ACL, AD[ 6:0], CSSA & WR, ID, DTSA, VCL, SPAAD, SPADT ); 
PALETRAM		pr( ACL, AD[ 8:0], CSPL & WR, ID, DTPL, VCL, PALAD, PALDT );

assign OD = CSFG ? DTFG :
				CSBG ? DTBG :
				CSSA ? DTSA :
				CSPL ? DTPL : 8'h0;

assign DV = CSFG|CSBG|CSSA|CSPL;

endmodule


module FG
(
	input					VCLKx2,
	input					VCLK,

	input  [8:0]		PH,
	input	 [8:0]		PV,

	output reg [9:0]	VAD,
	input  [15:0]		VDT,

	output reg [6:0]	OUT,
	
	input					DLCL,
	input  [19:0]		DLAD,
	input	  [7:0]		DLDT,
	input					DLEN
);

reg  [19:0] CAD;
wire  [7:0] CDT;
FGROM ch( VCLKx2, CAD[15:0], CDT, DLCL,DLAD,DLDT,DLEN ); 

always @( posedge VCLKx2 ) VAD <= {PV[7:3],PH[7:3]};

wire [10:0] CNO = VDT[10:0];
wire  [2:0] PAL = VDT[14:12];
wire  [3:0] CPX = CAD[19] ? CDT[3:0] : CDT[7:4];

always @( posedge VCLK ) begin
	CAD <= {PH[0],PAL,CNO,PV[2:0],PH[2:1]};
end
always @(negedge VCLK) OUT <= {CAD[18:16],CPX};

endmodule


module BG
(
	input					VCLKx2,
	input					VCLK,

	input  [8:0]		PH,
	input	 [8:0]		PV,

	output reg [9:0]	VAD,
	input  [15:0]		VDT,

	output reg [6:0]	OUT,

	input					DLCL,
	input  [19:0]		DLAD,
	input	  [7:0]		DLDT,
	input					DLEN
);

reg  [20:0] CAD;
wire  [7:0] CDT;
BGROM ch( VCLKx2, CAD[15:0], CDT, DLCL,DLAD,DLDT,DLEN );

wire [10:0] CNO = VDT[10:0];
wire  [2:0] PAL = VDT[14:12];
wire			HFL = VDT[15];
wire			VFL = VDT[11];
wire  [3:0] CPX = (CAD[20]^CAD[19]) ? CDT[3:0] : CDT[7:4]; 

always @( posedge VCLKx2 ) VAD <= {PV[7:3],PH[7:3]};

always @( posedge VCLK ) begin
	CAD <= {PH[0],HFL,PAL,CNO,(PV[2:0]^{3{VFL}}),(PH[2:1]^{2{HFL}})};
end
always @( negedge VCLK ) OUT <= {CAD[18:16],CPX};

endmodule


module SP
(
	input					VCLKx4,
	input					VCLK,

	input	 [8:0]		PH,
	input	 [8:0]		PV,

	output [6:0]		SPAAD,
	input	 [7:0]		SPADT,

	output reg [6:0]	POUT,

	input					DLCL,
	input  [19:0]		DLAD,
	input	  [7:0]		DLDT,
	input					DLEN
);

function [3:0] XOUT;
input  [2:0] N;
input [31:0] CDT;
	case(N)
	 0: XOUT = {CDT[0],CDT[ 8],CDT[16],CDT[24]};
	 1: XOUT = {CDT[1],CDT[ 9],CDT[17],CDT[25]};
	 2: XOUT = {CDT[2],CDT[10],CDT[18],CDT[26]};
	 3: XOUT = {CDT[3],CDT[11],CDT[19],CDT[27]};
	 4: XOUT = {CDT[4],CDT[12],CDT[20],CDT[28]};
	 5: XOUT = {CDT[5],CDT[13],CDT[21],CDT[29]};
	 6: XOUT = {CDT[6],CDT[14],CDT[22],CDT[30]};
	 7: XOUT = {CDT[7],CDT[15],CDT[23],CDT[31]};
	endcase
endfunction

reg	[4:0] SPRNO;
reg	[1:0] SPRIX;
assign		SPAAD = {SPRNO,SPRIX};

reg	[7:0]	A0,A1,SY,SX;
wire  [8:0]	CHRNO = {A1[4],A0};
wire  [2:0] PALNO = A1[3:1];
wire			FLIPH = A1[6];
wire			FLIPV = A1[7];

reg   [7:0]	NV;
wire	[7:0]	HY   = (NV-SY);
wire			HITY = (HY[7:4]==4'b1111);

reg	[4:0] WC;
wire	[3:0]	LX   = WC[3:0]^{4{FLIPH}};
wire	[3:0]	LY   = HY[3:0]^{4{FLIPV}};
wire [13:0] CAD  = {CHRNO,LY[3],~LX[3],LY[2:0]};
wire [31:0] CDT;

wire  [8:0]	WPOS = {1'b0,SX};
wire  [6:0]	WPIX = {PALNO,XOUT(LX[2:0],CDT)};
wire			WPEN = (~WC[4]) & (WPIX[3:0]!=0);
wire			WSID = PV[0];

wire			HDSP = (~PH[8]);


`define WAIT	0
`define FETCH0	1
`define FETCH1	2
`define FETCH2	3
`define FETCH3	4
`define DRAW	5
`define NEXT	6
`define TERM	7

reg [2:0] STATE;
always @( posedge VCLKx4 ) begin
	case (STATE)

	 `WAIT: begin
			WC <= 16;
			if (HDSP) begin
				NV    <= PV-16;
				SPRNO <= 31;
				SPRIX <= 2;
				STATE <= `FETCH0;
			end
		end

	 `FETCH0: begin
			SY    <= 240-SPADT;
			SPRIX <= 0;
			STATE <= `FETCH1;
		end

	 `FETCH1: begin
			A0    <= SPADT;
			SPRIX <= 1;
			STATE <= HITY ? `FETCH2 : `NEXT;
		end
	 
	 `FETCH2: begin
			A1    <= SPADT;
			SPRIX <= 3;
			STATE <= `FETCH3;
		end

	 `FETCH3: begin
			SX    <= SPADT;
			WC    <= 15;
			STATE <= `DRAW;
		end

	 `DRAW: begin
			SX    <= SX+1;
			WC    <= WC-1;
			STATE <= (WC==0) ? `NEXT : STATE;
		end

	 `NEXT: begin
			SPRNO <= SPRNO-1;
			SPRIX <= 2;
			STATE <= (SPRNO==0) ? `TERM : `FETCH0; 
		end

	 `TERM: begin
			STATE <= HDSP ? STATE : `WAIT;
	   end

	endcase
end


SPROM	ch( ~VCLKx4, CAD, CDT, DLCL,DLAD,DLDT,DLEN );

reg  [9:0] adrs0=0,adrs1=1;
wire [6:0] oPIX;
always @(posedge VCLK) adrs0 <= {~WSID,PH};
always @(negedge VCLK) begin
	if (adrs1!=adrs0) POUT <= oPIX;
	adrs1 <= adrs0;
end
LineDBuf lbuf(
	 VCLKx4, adrs0, oPIX, (adrs0==adrs1),
	 VCLKx4, { WSID,WPOS}, WPIX, WPEN
);

endmodule

