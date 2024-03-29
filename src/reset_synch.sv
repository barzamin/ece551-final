/*------------------------------------------------------------------------------
--  This module takes the RST_n signal and produces the rst_n signal that is 
--  used throughout the design.
--
--  Team: MEI
--  Authors:
--    * Mitchell Kitzinger
--    * Erin Marshall
--    * Isaac Colbert
--  Term: Spring 2021
------------------------------------------------------------------------------*/
module reset_synch (
  input logic RST_n, // raw reset input
  input logic clk,   // clock
  output reg rst_n   // synchronized reset
);

	// Internal signals
	logic q1;

	// 2 negative edge controlled flops
	always_ff @(negedge clk, negedge RST_n) begin
		if (!RST_n) begin
			q1 <= 1'b0;
			rst_n <= 1'b0;
		end else begin
			q1 <= 1'b1;
			rst_n <= q1;
		end
	end
endmodule