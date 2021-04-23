module cmd_cfg(clk, rst_n, cmd_rdy, cmd, data, clr_cmd_rdy, resp, send_resp, d_ptch, d_roll, d_yaw, 
				thrst, strt_cal, inertial_cal, cal_done, motors_off);

	parameter FAST_SIM = 1'b1;

	input clk, rst_n;                        	// Clock and global reset
	input cmd_rdy;                            	// Indicates the UART has a new command
	input [7:0] cmd;                        	// Command opcode from UART
	input [15:0] data;                        	// Command data from UART
	input cal_done;                            	// Indicates interial calibration is complete

	output reg clr_cmd_rdy;                     // clrs cmd_rdy after cmd_cfg digested command
	output [7:0] resp;                       	// response back to remote, typically pos_ack(0xA5);
	output reg send_resp;                      	// indicates UART_comm should send response byte
	output reg [15:0] d_ptch, d_roll, d_yaw;    // desired pitch, roll, yaw as 16-bit signed numbers
	output reg [8:0] thrst;                     // 9-bit unsigned thrust level, goes to flight_cntrl
	output reg strt_cal;                      	// indicates to inertial_integrater to start calibration procedure
	output reg inertial_cal;                   	// to flight_cntrl unit. Held high during duration of calibration
	output reg motors_off;                     	// goes to ESCs, shuts off motors

	logic wptch, wroll, wyaw, wthrst, clr_tmr;
	logic tmr_full, mtrs_off, emer_cntrl;
	logic [25:0] tmr;

	localparam pos_ack = 8'hA5;
	
	// localparams for cmd encodings
	localparam SET_PTCH = 8'h02;
	localparam SET_ROLL = 8'h03;
	localparam SET_YAW = 8'h04;
	localparam SET_THRST = 8'h05;
	localparam CALIBRATE = 8'h06;
	localparam EMER_LAND = 8'h07;
	localparam MTRS_OFF = 8'h08;
	
	// States enumeration
	typedef enum reg[1:0] {INTERP, WAIT_MTR_RAMP, WAIT_CAL_DONE, RESP} state_t;
	state_t state, nxt_state;

	// Holding register for d_ptch
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			d_ptch <= 16'h0000;
		else if (emer_cntrl)
			d_ptch <= 16'h0000;
		else if (wptch)
			d_ptch <= data;
	end
	
	// Holding register for d_roll
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			d_roll <= 16'h0000;
		else if (emer_cntrl)
			d_roll <= 16'h0000;
		else if (wroll)
			d_roll <= data;
	end
	
	// Holding register for d_yaw
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			d_yaw <= 16'h0000;
		else if (emer_cntrl)
			d_yaw <= 16'h0000;
		else if (wyaw)
			d_yaw <= data;
	end
	
	// Holding register for thrst
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			thrst <= 9'h000;
		else if (emer_cntrl)
			thrst <= 9'h000;
		else if (wthrst)
			thrst <= data[8:0];
	end
	
	// motor ramp timer
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			tmr <= 26'h0000000;
		else if (clr_tmr)
			tmr <= 26'h0000000;
		else
			tmr <= tmr + 1;
	end
	
	// Assert tmr_full at 9 full bits or 26 full bits, depending on FAST_SIM
	generate
		if (FAST_SIM) begin
			assign tmr_full = (tmr == 26'h00001FF) ? 1'b1 : 1'b0;
		end else begin
			assign tmr_full = (&tmr) ? 1'b1 : 1'b0;
		end
	endgenerate
	
	// Output flop
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			motors_off <= 1'b1;
		else if (mtrs_off)
			motors_off <= 1'b1;
		else if (inertial_cal)
			motors_off <= 1'b0;
	end
	
	// set resp to pos_ack, only assert snd_resp after
	// a cmd has been processed
	assign resp = pos_ack;
	
	// State flop
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			state <= INTERP;
		else
			state <= nxt_state;
	end
	
	// State machine transition and output logic
	always_comb begin
		//// Default outputs ////
		// Write sigs
		wptch = 1'b0;
		wroll = 1'b0;
		wyaw = 1'b0;
		wthrst = 1'b0;
		// Calibration sigs
		inertial_cal = 1'b0;
		strt_cal = 1'b0;
		clr_tmr = 1'b0;
		// Resp sig
		send_resp = 1'b0;
		// Emer land sig
		emer_cntrl = 1'b0;
		// Mtrs off sig
		mtrs_off = 1'b0;
		// clr_cmd_rdy sig for UART
		clr_cmd_rdy = 1'b0;
		// Next state default
		nxt_state = state;
		
		case(state)
			WAIT_MTR_RAMP: begin
				inertial_cal = 1'b1;
				if (tmr_full) begin
					inertial_cal = 1'b1;
					strt_cal = 1'b1;
					nxt_state = WAIT_CAL_DONE;
				end
			end
			WAIT_CAL_DONE: begin
				if (cal_done) begin
					nxt_state = RESP;
				end else begin
					inertial_cal = 1'b1;
				end
			end
			RESP: begin
				send_resp = 1'b1;
				nxt_state = INTERP;
			end
			//// Default state: INTERP ////
			default: begin
				if (cmd_rdy) begin
					case(cmd)
						SET_PTCH: begin
							wptch = 1'b1;
							clr_cmd_rdy = 1'b1;
							nxt_state = RESP;
						end
						SET_ROLL: begin
							wroll = 1'b1;
							clr_cmd_rdy = 1'b1;
							nxt_state = RESP;
						end
						SET_YAW: begin
							wyaw = 1'b1;
							clr_cmd_rdy = 1'b1;
							nxt_state = RESP;
						end
						SET_THRST: begin
							wthrst = 1'b1;
							clr_cmd_rdy = 1'b1;
							nxt_state = RESP;
						end
						CALIBRATE: begin
							inertial_cal = 1'b1;
							clr_tmr = 1'b1;
							clr_cmd_rdy = 1'b1;
							nxt_state = WAIT_MTR_RAMP;
						end
						EMER_LAND: begin
							emer_cntrl = 1'b1;
							clr_cmd_rdy = 1'b1;
							nxt_state = RESP;
						end
						//// Default cmd: MTRS_OFF ////
						default: begin
							mtrs_off = 1'b1;
							clr_cmd_rdy = 1'b1;
							nxt_state = RESP;
						end
					endcase
				end
			end
		endcase
	end
	

endmodule