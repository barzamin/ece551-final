module ESC_interface_tb();
	logic clk, rst_n, wrt;
	logic PWM;
	logic [10:0] SPEED;
	logic [15:0] high_cnt;
	
	ESC_interface_pipeline iDUT(.clk(clk),.rst_n(rst_n),.wrt(wrt),
						.SPEED(SPEED),.PWM(PWM));
	
	initial begin
		clk = 0;
		rst_n = 0;
		wrt = 0;
		
		// Case 1, SPEED is set to 0
		SPEED = 11'h000;
		@(negedge clk);
		rst_n = 1;
		repeat (2) @(posedge clk);		// wait after deasserting asynch reset
		@(negedge clk);
		wrt = 1;
		@(negedge clk);					// wait a clk cycle
		wrt = 0;
		high_cnt = 16'h0000;
		
		//@(posedge clk);					// wait a clock cycle for PWM to catch up
		
		while(PWM !== 1'b0) begin
			@(negedge clk) high_cnt = high_cnt + 1;
		end
		if (high_cnt !== 6251) begin // answer is currently off by 1
			$display("ERR: PWM was not high for the correct amount of time.");
			$display("Target time: 6250, TB with off by one: 6251");
			$display("Expected: 6251, Returned: %d",high_cnt);
		end
		
		// Case 2, SPEED is set to half of maximum
		SPEED = 11'h400;
		@(negedge clk);
		rst_n = 1;
		wrt = 1;
		@(negedge clk);
		wrt = 0;
		high_cnt = 16'h0000;
		
		//@(posedge clk);					// wait a clock cycle for PWM to catch up
		
		while(PWM !== 1'b0) begin
			@(negedge clk) high_cnt = high_cnt + 1;
		end	
		@(posedge clk);
		if (high_cnt !== 9323) begin // answer is currently off by 1
			$display("ERR: PWM was not high for the correct amount of time.");
			$display("Target time: 9322, TB with off by one: 9323");
			$display("Expected: 9323, Returned: %d",high_cnt);
		end
		
		$display("Test passed!");
		$stop();
	end
	
	always
		#1 clk = ~clk;
endmodule