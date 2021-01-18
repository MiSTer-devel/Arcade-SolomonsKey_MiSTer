//	Copyright (c) 2014,19 MiSTer-X

module MAINROM
(
	input				CL,
	input  [15:0]	AD,
	output  [7:0]	DT,
	output			DV,

	input				DLCL,
	input  [19:0]	DLAD,
	input	  [7:0]	DLDT,
	input				DLEN
);
/*
	34000-37FFF   MAINCPU0
	38000-3FFFF   MAINCPU1 (4000h swaped)
	40000-40FFF   MAINCPU2
*/
wire [7:0] dt0, dt1, dt2, dt3;
DLROM #(14,8) r0( CL, AD[13:0], dt0, DLCL,DLAD,DLDT,DLEN & (DLAD[19:14]==6'b0011_01) );
DLROM #(14,8) r1( CL, AD[13:0], dt1, DLCL,DLAD,DLDT,DLEN & (DLAD[19:14]==6'b0011_11) );
DLROM #(14,8) r2( CL, AD[13:0], dt2, DLCL,DLAD,DLDT,DLEN & (DLAD[19:14]==6'b0011_10) );
DLROM #(12,8) r3( CL, AD[11:0], dt3, DLCL,DLAD,DLDT,DLEN & (DLAD[19:12]==8'b0100_0000) );

wire	dv0 = (AD[15:14]==2'b00);
wire	dv4 = (AD[15:14]==2'b01);
wire  dv8 = (AD[15:14]==2'b10);
wire  dvF = (AD[15:12]==4'b1111);

assign DT = dvF ? dt3 :
				dv8 ? dt2 :
				dv4 ? dt1 :
				dv0 ? dt0 : 8'h0;
				
assign DV = dvF|dv8|dv4|dv0;				

endmodule


module FGROM
(
	input 			CL,
	input  [15:0] 	AD,
	output  [7:0]	DT,
	
	input				DLCL,
	input  [19:0]	DLAD,
	input	  [7:0]	DLDT,
	input				DLEN
);
/*
	10000-17FFF   FGCHIP0
	18000-1FFFF   FGCHIP1
*/
DLROM #(16,8) r(CL,AD,DT, DLCL,DLAD,DLDT,DLEN & (DLAD[19:16]==4'd1) );

endmodule


module BGROM
(
	input 			CL,
	input  [15:0] 	AD,
	output  [7:0]	DT,

	input				DLCL,
	input  [19:0]	DLAD,
	input	  [7:0]	DLDT,
	input				DLEN
);
/*
	20000-27FFF   BGCHIP0
	28000-2FFFF   BGCHIP1
*/
DLROM #(16,8) r(CL,AD,DT, DLCL,DLAD,DLDT,DLEN & (DLAD[19:16]==4'd2) );

endmodule


module SPROM
(
	input				CL,
	input	 [13:0]	AD,
	output [31:0]	DT,

	input				DLCL,
	input  [19:0]	DLAD,
	input	  [7:0]	DLDT,
	input				DLEN
);
/*
	00000-03FFF   SPCHIP0
	04000-07FFF   SPCHIP1
	08000-0BFFF   SPCHIP2
	0C000-0FFFF   SPCHIP3
*/
wire [7:0] dt0,dt1,dt2,dt3;
DLROM #(14,8) r0( CL, AD, dt0, DLCL,DLAD,DLDT,DLEN & (DLAD[19:14]==6'b0000_00) );
DLROM #(14,8) r1( CL, AD, dt1, DLCL,DLAD,DLDT,DLEN & (DLAD[19:14]==6'b0000_01) );
DLROM #(14,8) r2( CL, AD, dt2, DLCL,DLAD,DLDT,DLEN & (DLAD[19:14]==6'b0000_10) );
DLROM #(14,8) r3( CL, AD, dt3, DLCL,DLAD,DLDT,DLEN & (DLAD[19:14]==6'b0000_11) );

assign DT = {dt3,dt2,dt1,dt0};

endmodule


module SNDROM
(
	input				CL,
	input	 [13:0]	AD,
	output  [7:0]	DT,

	input				DLCL,
	input  [19:0]	DLAD,
	input	  [7:0]	DLDT,
	input				DLEN
);
// 30000-33FFF   SNDCPU
DLROM #(14,8) r(CL,AD,DT, DLCL,DLAD,DLDT,DLEN & (DLAD[19:14]==6'b0011_00));

endmodule



module DLROM #(parameter AW,parameter DW)
(
	input							CL0,
	input [(AW-1):0]			AD0,
	output reg [(DW-1):0]	DO0,

	input							CL1,
	input [(AW-1):0]			AD1,
	input	[(DW-1):0]			DI1,
	input							WE1
);

reg [(DW-1):0] core[0:((2**AW)-1)];

always @(posedge CL0) DO0 <= core[AD0];
always @(posedge CL1) if (WE1) core[AD1] <= DI1;

endmodule

