module PD_math_pipeline(pterm, dterm, clk, rst_n, vld, desired, actual);

	output logic [9:0] pterm;
	output logic signed [11:0] dterm;
	input clk, rst_n, vld;
	input [15:0] actual, desired;
	
	localparam DTERM = 5'b00111;
	localparam D_QUEUE_DEPTH = 12;

	logic [16:0] err;
	logic [9:0] err_sat, D_diff;
	logic [6:0] D_diff_sat;
	reg [9:0] prev_err[0:D_QUEUE_DEPTH-1];
	logic [9:0] err_sat_half, err_sat_eighth;
	
	// type logic for pipeline reg
	logic [6:0] D_diff_sat_ff;
	//logic signed [10:0] dterm_ff;
	logic signed [9:0] pterm_ff;
	
	genvar i;

	assign err = {actual[15],actual} - {desired[15],desired};
	
	// Saturate err to 10 bits
	assign err_sat = (err[16]) ?
						((&err[15:9] == 0) ? 10'h200 : err[9:0]) :
						((|err[15:9]) ? 10'h1ff : err[9:0]);
	
	//////////////////////////////////////////////
	// Parametizable Queue depth for Derivative //
	//////////////////////////////////////////////
	generate
		for (i = 0; i < D_QUEUE_DEPTH; i = i + 1) begin
			always_ff @(posedge clk, negedge rst_n) begin
				if (!rst_n)
					prev_err[i] <= 10'h000;
				else if (vld)
					if (i == 0) begin
						prev_err[0] <= err_sat;
					end else begin
						prev_err[i] <= prev_err[i-1];
					end
			end
		end
	endgenerate
		
	// Subtract past error from current error to approximate derivative
	assign D_diff = err_sat - prev_err[D_QUEUE_DEPTH-1];
	
	// Saturate D_diff to 7 bits
	assign D_diff_sat = (D_diff[9]) ?
							((&D_diff[8:6] == 0) ? 7'h40 : D_diff[6:0]) :
							((|D_diff[8:6]) ? 7'h3f : D_diff[6:0]);
	
	// Pipeline register for d_term before multiplying
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			D_diff_sat_ff <= 7'h00;
		else
			D_diff_sat_ff <= D_diff_sat;
	end
	
	// Signed multiply of D_diff_sat
	assign dterm = $signed(D_diff_sat_ff) * $signed(DTERM);
	
	/*always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			dterm <= 11'h000;
		else 
			dterm <= dterm_ff;
	end*/
	
	// Shift err_sat right once to divide by two, sign extending msb
	assign err_sat_half = {err_sat[9], err_sat[9:1]};
	// Shift err_sat right three times to divide by eight, sign extending msb
	assign err_sat_eighth = {err_sat[9], err_sat[9], err_sat[9], err_sat[9:3]};

	// Add together the eighth and half to calculate 5/8
	assign pterm_ff = err_sat_half + err_sat_eighth;
	
	// Pipeline register for p_term after adding
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			pterm <= 10'h000;
		else
			pterm <= pterm_ff;
	end

endmodule