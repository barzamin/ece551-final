module reset_synch(RST_n, clk, rst_n);
	
	// Inputs and outputs
	input RST_n, clk;
	output reg rst_n;
	
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