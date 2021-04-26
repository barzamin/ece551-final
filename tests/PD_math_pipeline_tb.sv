module PD_math_pipeline_tb();

	logic [9:0] pterm;
	logic [11:0] dterm;
	logic clk, rst_n, vld;
	logic [15:0] actual, desired;

	logic [9:0] pterm_p;
	logic [11:0] dterm_p;
	logic vld_p;
	logic [15:0] actual_p, desired_p;

	// Instantiate normal version
	PD_math	iDUT(.pterm(pterm), .dterm(dterm), .clk(clk), .rst_n(rst_n), .vld(vld),
				.actual(actual), .desired(desired));

	// Instantiate pipeline
	PD_math_pipeline pDUT(.pterm(pterm_p), .dterm(dterm_p), .clk(clk), .rst_n(rst_n), .vld(vld_p),
						.actual(actual), .desired(desired));


	initial begin
		clk = 0;
		rst_n = 1'b0;
		repeat (2) @(posedge clk);
		rst_n = 1'b1;

		desired = 16'b0101100101011011;
		actual = 16'b0101100101001101;

		vld = 1'b1;
		vld_p = 1'b1;

		@(posedge clk);

		vld = 1'b0;
		vld_p = 1'b0;

		desired = 16'h23c4;
		actual = 16'h2307;

		@(posedge clk);

		vld = 1'b1;
		vld_p = 1'b1;

		desired = 16'h24A1;
		actual = 16'h2391;

		repeat (10) @(posedge clk);
		$stop();
	end

	always
		#5 clk = ~clk;
endmodule