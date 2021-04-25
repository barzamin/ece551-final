module PD_math_pipeline_tb();
	
	logic [9:0] pterm;
	logic [11:0] dterm;
	logic clk, rst_n, vld;
	logic [15:0] actual, desired;
	
	logic [9:0] pterm_p;
	logic [11:0] dterm_p;
	logic clk, rst_n, vld_p;
	logic [15:0] actual_p, desired_p;
	
	// Instantiate normal version
	PD_math(
	
	
	initial begin
	
	end
	
	always
		#5 clk = ~clk;
endmodule;