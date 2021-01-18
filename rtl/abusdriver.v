
module DSEL4D
(
	output [7:0] out,
	input			 en,

	input			 en0,
	input	 [7:0] dt0,
	input			 en1,
	input	 [7:0] dt1,
	input			 en2,
	input	 [7:0] dt2,
	input			 en3,
	input	 [7:0] dt3
);

wire [7:0] o = en0 ? dt0 :
					en1 ? dt1 :
					en2 ? dt2 :
					en3 ? dt3 :
					8'h0;

assign out = en ? o : 8'h0;

endmodule


module DSEL3D
(
	output [7:0] out,
	input			 en,
	
	input			 en0,
	input	 [7:0] dt0,
	input			 en1,
	input	 [7:0] dt1,
	input			 en2,
	input	 [7:0] dt2
);

wire [7:0] o = en0 ? dt0 :
					en1 ? dt1 :
					en2 ? dt2 :
					8'h0;

assign out = en ? o : 8'h0;

endmodule

