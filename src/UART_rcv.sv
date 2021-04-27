module UART_rcv(clk, rst_n, RX, clr_rdy, rx_data, rdy);
	
	input clk, rst_n, RX, clr_rdy;
	output reg rdy;
	output [7:0] rx_data;
	
	// intermediate declarations
	logic init, receiving, shift, set_rdy;
	logic [8:0] rx_shift_reg;
	logic [11:0] baud_cnt;
	logic [3:0] bit_cnt;
	logic RX_q1, RX_q2;
	
	// state declarations
	typedef enum reg {IDLE, REC} state_t;
	state_t state, nxt_state;
	
	// state machine
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;
	end
	
	// state machine combinational logic
	always_comb begin
		//// Default outputs ////
		init = 0;
		receiving = 0;
		set_rdy = 0;
		nxt_state = state;
		
		case(state)
			REC: if (bit_cnt == 10) begin
				set_rdy = 1'b1;
				nxt_state = IDLE;
			end else begin
				receiving = 1'b1;
				nxt_state = REC;
			end
			//// Default Case: IDLE ////
			default: if (RX_q2 == 0) begin
				init = 1'b1;
				nxt_state = REC;
			end else begin
				nxt_state = IDLE;
			end
		endcase
	end
	
	// Double flop RX for metastability
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			RX_q1 <= 1'b1;
			RX_q2 <= 1'b1;
		end else begin
			RX_q1 <= RX;
			RX_q2 <= RX_q1;
		end
	end;
	
	// Shift Register logic
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			rx_shift_reg <= 8'hFF;
		end else if (shift) begin
			rx_shift_reg <= {RX_q2, rx_shift_reg[8:1]};
		end
	end
	// RX comes into msb, so assign rx_data to lower 8 bits of
	// the shift register to get data and avoid stop bit_cnt
	assign rx_data = rx_shift_reg[7:0];
	
	// Baud counter
	always_ff @(posedge clk) begin
		// Choose whether using 1/2 period or full depending on if 
		// init is asserted
		if (init) begin
			baud_cnt <= 12'h516;
		end else if (shift) begin
			baud_cnt <= 12'hA2C;
		end else if (receiving) begin
			baud_cnt <= baud_cnt - 1;
		end
	end
	
	// Compare baud_cnt to 0 to determine if period is over
	assign shift = (|baud_cnt == 0) ? 1'b1 : 1'b0;
	
	// Bit Counter
	always_ff @(posedge clk) begin
		if (init) begin
			bit_cnt <= 4'h0;
		end else if (shift) begin
			bit_cnt <= bit_cnt + 1;
		end
	end
	
	// Output logic and flop
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			rdy <= 1'b0;
		else if (set_rdy)
			rdy <= 1'b1;
		else if (init)
			rdy <= 1'b0;
		else if (clr_rdy)
			rdy <= 1'b0;
	end
endmodule