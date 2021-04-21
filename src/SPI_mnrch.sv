module SPI_mnrch(clk, rst_n, SS_n, SCLK, MOSI, MISO, wrt, wt_data, done, rd_data);
	output [15:0] rd_data;
	output reg done, SS_n;
	output SCLK, MOSI;
	input [15:0] wt_data;
	input clk, rst_n, wrt, MISO;
	
	// Intermediate signals
	logic [4:0] bit_cntr;
	logic init, ld_SCLK, SCLK, shft, set_done, done16;
	logic [3:0] SCLK_div;
	logic [15:0] shft_reg;
	
	// States
	typedef enum reg[1:0] {IDLE, TRANS, TEARDOWN} state_t;
	state_t state, nxt_state;
	
	// 16-bit counter
	always_ff @(posedge clk) begin
		if (init) begin
			bit_cntr <= 5'b00000;
		end else if (shft) begin
			bit_cntr <= bit_cntr + 1;
		end
	end
	assign done16 = (bit_cntr[4]) ? 1'b1 : 1'b0;
	
	// SCLK structure
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			SCLK_div <= 4'b1011;
		end else if (ld_SCLK) begin
			SCLK_div <= 4'b1011;
		end else begin
			SCLK_div <= SCLK_div + 1;
		end
	end
	// SCLK goes high when msb of SCLK_div is high
	assign SCLK = SCLK_div[3];
	// Shift 2 clock cycles after SCLK goes high
	assign shft = (SCLK_div == 4'h9) ? 1'b1 : 1'b0;
	
	// Shift register
	always_ff @(posedge clk) begin
		if (init) begin
			shft_reg <= wt_data;
		end else if (shft) begin
			shft_reg <= {shft_reg[14:0], MISO};
		end
	end
	// Assign MOSI to msb of shft_reg
	assign MOSI = shft_reg[15];
	// The read data is the shift reg
	assign rd_data = shft_reg;
	
	// State machine reg
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;
	end
	
	// State machine combinational logic
	always_comb begin
		//// Default outputs ////
		init = 1'b0;
		set_done = 1'b0;
		SS_n = 1'b0;
		ld_SCLK = 1'b0;
		nxt_state = state;
		
		// Transitions based on inputs and state
		case(state)
			TRANS: if (done16) begin
					nxt_state = TEARDOWN;
				end else begin
					nxt_state = TRANS;
				end
			// Only do upper 3 bits to check when == 14, avoid SCLK going low
			// at same time as transition to IDLE
			TEARDOWN: if (&SCLK_div[3:1]) begin
					nxt_state = IDLE;
					SS_n = 1'b1;
					set_done = 1'b1;
				end else begin
					nxt_state = TEARDOWN;
				end
			//// Default state: IDLE ////
			default: begin
				// SS_n should be high whenever in IDLE
				SS_n = 1'b1;
				ld_SCLK = 1'b1;
				if (wrt) begin
					init = 1'b1;
					nxt_state = TRANS;
				end else begin
					nxt_state = IDLE;
				end
				end
		endcase
	end
	
	// Done SR flop
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			done <= 1'b0;
		end else if (init) begin
			done <= 1'b0;
		end else if (set_done) begin
			done <= 1'b1;
		end
	end
	
endmodule