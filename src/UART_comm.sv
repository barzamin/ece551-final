module UART_comm(clk, rst_n, RX, TX, resp, send_resp, resp_sent, cmd_rdy, cmd, data, clr_cmd_rdy);

	input clk, rst_n;		// clock and active low reset
	input RX;				// serial data input
	input send_resp;		// indicates to transmit 8-bit data (resp)
	input [7:0] resp;		// byte to transmit
	input clr_cmd_rdy;		// host asserts when command digested

	output TX;				// serial data output
	output resp_sent;		// indicates transmission of response complete
	output logic cmd_rdy;		// indicates 24-bit command has been received
	output logic [7:0] cmd;		// 8-bit opcode sent from host via BLE
	output logic [15:0] data;	// 16-bit parameter sent LSB first via BLE

	wire [7:0] rx_data;		// 8-bit data received from UART
	wire rx_rdy;			// indicates new 8-bit data ready from UART
	reg clr_rx_rdy;		// clear the ready for UART RX line

	////////////////////////////////////////////////////
	// declare any needed internal signals/registers //
	// below including any state definitions        //
	/////////////////////////////////////////////////
	logic capture_high, capture_mid;
	logic clr_cmd_rdy_i, set_cmd_rdy;
	
	// States of SM
	typedef enum reg [1:0] {HIGH, MID, LOW} state_t;
	state_t state, nxt_state;

	///////////////////////////////////////////////
	// Instantiate basic 8-bit UART transceiver //
	/////////////////////////////////////////////
	UART iUART(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .tx_data(resp), .trmt(send_resp),
						.tx_done(resp_sent), .rx_data(rx_data), .rx_rdy(rx_rdy), .clr_rx_rdy(clr_rx_rdy));
		
	////////////////////////////////
	// Implement UART_comm below //
	//////////////////////////////
	
	// cmd byte holder
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			cmd <= 8'h00;
		else if (capture_high)
			cmd <= rx_data;
	end
	
	// upper byte of data holder
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			data[15:8] <= 8'h00;
		else if (capture_mid)
			data[15:8] <= rx_data;
	end
	
	// assign data's lower byte to rx_data
	assign data[7:0] = rx_data;
	
	// Output flop
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			cmd_rdy <= 1'b0;
		else if (clr_cmd_rdy)
			cmd_rdy <= 1'b0;
		else if (clr_cmd_rdy_i)
			cmd_rdy <= 1'b0;
		else if (set_cmd_rdy)
			cmd_rdy <= 1'b1;
	end
	
	// Flops for SM
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			// Reset into HIGH
			state <= HIGH;
		else
			state <= nxt_state;
	end
	
	// Combinational logic for SM
	always_comb begin
		//// Default outputs ////
		nxt_state = state;
		clr_cmd_rdy_i = 1'b0;
		set_cmd_rdy = 1'b0;
		capture_high = 1'b0;
		capture_mid = 1'b0;
		clr_rx_rdy = 1'b0;
		
		// Transitions based on state
		case (state)
			MID: if (rx_rdy) begin
				capture_mid = 1'b1;
				clr_rx_rdy = 1'b1;
				nxt_state = LOW;
			end else begin
				nxt_state = MID;
			end
			LOW: if (rx_rdy) begin
				set_cmd_rdy = 1'b1;
				clr_rx_rdy = 1'b1;
				nxt_state = HIGH;
			end else begin
				nxt_state = LOW;
			end
			//// Default state = HIGH ////
			default: if (rx_rdy) begin
				capture_high = 1'b1;
				clr_cmd_rdy_i = 1'b1;
				clr_rx_rdy = 1'b1;
				nxt_state = MID;
			end else begin
				nxt_state = HIGH;
			end
		endcase
	end
	

endmodule	