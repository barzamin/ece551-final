/*------------------------------------------------------------------------------
--  Team MEI - Ex21 cmd_cfg_tb
------------------------------------------------------------------------------*/
`default_nettype none
module cmd_cfg_tb();
  // Clock and global reset
  logic clk, rst_n;
  // clockgen
  initial clk = 0;
  always #5 clk = ~clk;

  // -- remote side
  // REMOTE inputs
  logic [7:0]  rmt_cmd;
  logic [15:0] rmt_data;
  logic        rmt_snd_cmd;
  logic        rmt_clr_resp_rdy;

  // REMOTE outputs
  logic [7:0] rmt_resp;
  logic       rmt_resp_rdy;
  logic       rmt_cmd_sent;

  // -- barrier between remote and quad (simulates BLE)
  // REMOTE outputs / UART inputs
  logic TX_RX, RX_TX;

  // -- quad side
  // UART outputs / DUT inputs
  logic DUT_cmd_rdy;
  logic [7:0] DUT_cmd;
  logic [15:0] DUT_data;

  // DUT outputs / UART inputs
  logic DUT_clr_cmd_rdy;
  logic [7:0] DUT_resp;
  logic DUT_send_resp;

  // DUT inputs
  logic cal_done;

  // DUT outputs
  logic [15:0] d_ptch, d_roll, d_yaw;
  logic [8:0] thrst;
  logic strt_cal;
  logic inertial_cal;
  logic motors_off;

  // UART outputs
  logic resp_sent;

  // remote-side transciever
  RemoteComm REMOTE(
    .clk          (clk),
    .rst_n        (rst_n),

    .RX           (RX_TX),
    .TX           (TX_RX),

    .cmd          (rmt_cmd),
    .data         (rmt_data),
    .send_cmd     (rmt_snd_cmd),
    .cmd_sent     (rmt_cmd_sent),
    .resp_rdy     (rmt_resp_rdy),
    .resp         (rmt_resp),
    .clr_resp_rdy (rmt_clr_resp_rdy)
  );

  // quadrotor-side transciever
  UART_comm UART(
    .clk         (clk),
    .rst_n       (rst_n),

    .RX          (TX_RX),
    .TX          (RX_TX),

    .cmd_rdy     (DUT_cmd_rdy),
    .cmd         (DUT_cmd),
    .data        (DUT_data),
    .clr_cmd_rdy (DUT_clr_cmd_rdy),
    .resp        (DUT_resp),
    .send_resp   (DUT_send_resp),
    .resp_sent   (resp_sent)
  );

  // quadrotor-side command decoder
  cmd_cfg #(.FAST_SIM(1'b1)) DUT(
    .clk          (clk),
    .rst_n        (rst_n),

    .cmd_rdy      (DUT_cmd_rdy),
    .cmd          (DUT_cmd),
    .data         (DUT_data),
    .clr_cmd_rdy  (DUT_clr_cmd_rdy),
    .resp         (DUT_resp),
    .send_resp    (DUT_send_resp),

    .d_ptch       (d_ptch),
    .d_roll       (d_roll),
    .d_yaw        (d_yaw),
    .thrst        (thrst),
    .strt_cal     (strt_cal),
    .inertial_cal (inertial_cal),
    .cal_done     (cal_done),
    .motors_off   (motors_off)
  );
  
  /*------------------------------------------------------------------------------
  --  Commands and responses.
  ------------------------------------------------------------------------------*/
  localparam CMD_SET_PTCH   = 8'h02; // 16'hpppp (signed  16bit)
  localparam CMD_SET_ROLL   = 8'h03; // 16'hrrrr (signed  16bit)
  localparam CMD_SET_YAW    = 8'h04; // 16'hyyyy (signed  16bit)
  localparam CMD_SET_THRST  = 8'h05; // 16'h0ttt (unsigned 9bit)
  localparam CMD_CALIBRATE  = 8'h06; // 16'hxxxx
  localparam CMD_EMER_LAND  = 8'h07; // 16'h0000
  localparam CMD_MTRS_OFF  = 8'h08; // 16'hxxxx

  localparam RESP_POS_ACK   = 8'ha5;

  /*------------------------------------------------------------------------------
  --  Tasks for test fluency. (def. here to access signals within testbench)
  ------------------------------------------------------------------------------*/
  localparam RESP_WAIT_TIMEOUT = 1000000; // cycles
  task remote_resp_wait();
    fork
      begin : resp_timeout
        repeat(RESP_WAIT_TIMEOUT) @(posedge clk);
        $display("[!] timeout waiting for `resp` after %d clk cycles", RESP_WAIT_TIMEOUT);
        $stop();
      end
      @(posedge rmt_resp_rdy) disable resp_timeout;
    join
  endtask

  localparam DECODE_WAIT_TIMEOUT = 1000000; // cycles
  localparam CALIBRATE_TIMEOUT = 1000;
  task quad_decode_wait();
    fork
      begin : decode_timeout
        repeat(DECODE_WAIT_TIMEOUT) @(posedge clk);
        $display("[!] timeout waiting for `DUT_clr_cmd_rdy` after %d clk cycles", DECODE_WAIT_TIMEOUT);
        $stop();
      end
      @(posedge DUT_clr_cmd_rdy) disable decode_timeout;
    join
  endtask

  task remote_send(input logic [7:0] s_cmd, input logic [15:0] s_data);
    // set up command
    @(negedge clk);
    rmt_cmd = s_cmd;
    rmt_data = s_data;

    // strobe send_cmd
    rmt_snd_cmd = 1;
    @(negedge clk)
    rmt_snd_cmd = 0;
	
	// Test if cmd is CALIBRATE
	if (s_cmd == CMD_CALIBRATE) begin
		// Wait for the cmd to be received
		fork 
			begin: CMD_RDY_TIMEOUT
				repeat (1000000) @(posedge clk);
				$display("[!] timeout waiting for calibrate cmd to be received");
				$stop();
			end
			begin
				@(posedge DUT.cmd_rdy) disable CMD_RDY_TIMEOUT;
			end
		join
		fork
			begin
				// Wait half a clock before checking inertial_cal
				@(negedge clk);
				assert (inertial_cal === 1'b1)
				else $fatal(1, "[!] inertial_cal is not high after sending calibrate cmd.");
				
				@(posedge DUT.tmr_full) disable CAL_TIMEOUT;
				// Wait half a clock before checking strt_cal and inertial_cal
				@(posedge clk);
				assert (strt_cal === 1'b1)
				else $fatal(1, "[!] strt_cal didn't go high after tmr_full came high.");
				assert (inertial_cal === 1'b1)
				else $fatal(1, "[!] inertial_cal is not high after tmr_full goes high.");
				
				// The next period after being high, strt_cal should be low
				@(posedge clk);
				assert (strt_cal === 1'b0)
				else $fatal(1, "[!] strt_cal stayed high too long.");
				assert (inertial_cal === 1'b1)
				else $fatal(1, "[!] inertial_cal is not high after strt_cal goes low.");
				
				cal_done = 1'b1;
				// Check that inertial_cal is low after cal_done goes high
				@(negedge clk);
				assert (inertial_cal === 1'b0)
				else $fatal(1, "[!] inertial_cal is not low after cal_done goes high.");
				// Set cal_done back to 0 for later tests
				@(negedge clk);
				cal_done = 1'b0;
			end
			begin: CAL_TIMEOUT
				repeat(CALIBRATE_TIMEOUT) @(posedge clk);
				$display("[!] timeout waiting for `tmr_full` after %d clk cycles", CALIBRATE_TIMEOUT);
				$stop();
			end
		join
	end
	
  endtask

  task remote_assertresp(input logic [7:0] tru_resp);
    assert (rmt_resp === tru_resp)
    else $fatal(1, "[remote] expected resp %h !== %h", tru_resp, rmt_resp);
  endtask
  
  initial begin
    // reset all devices
    @(negedge clk) rst_n = 0;
    @(negedge clk) rst_n = 1;
	
/*	// Set all outputs at start
	rmt_resp_rdy = 1'b0;
	cal_done = 1'b0;
	rmt_clr_resp_rdy = 1'b0;
	*/

	// -- CALIBRATE
	remote_send(CMD_CALIBRATE, 16'hxxxx);
	remote_resp_wait();
	remote_assertresp(RESP_POS_ACK);
	
	assert (motors_off === 1'b0)
	else $fatal(1, "[!] motors_off assert failed (is %h), should be %h", motors_off, 1'h1);

    // -- SET_PTCH
    remote_send(CMD_SET_PTCH, 16'h1337); // send set pitch from remote
    quad_decode_wait(); // wait for quad to process
    remote_resp_wait(); // wait for ack
    remote_assertresp(RESP_POS_ACK);
    assert (d_ptch === 16'h1337) // check pitch
    else $fatal(1, "[!] d_ptch assert failed (is %h), should be %h", d_ptch, 16'h1337);
	
	// -- SET_ROLL
	remote_send(CMD_SET_ROLL, 16'hAAAA);
	quad_decode_wait(); // wait for quad to process
	remote_resp_wait();
	remote_assertresp(RESP_POS_ACK);
	assert (d_roll === 16'hAAAA)
	else $fatal(1, "[!] d_roll assert failed (is %h), should be %h", d_roll, 16'hAAAA);
	
	// -- SET_YAW
	remote_send(CMD_SET_YAW, 16'hAAAA);
	quad_decode_wait(); // wait for quad to process
	remote_resp_wait();
	remote_assertresp(RESP_POS_ACK);
	assert (d_yaw === 16'hAAAA)
	else $fatal(1, "[!] d_yaw assert failed (is %h), should be %h", d_yaw, 16'hAAAA);
	
	// -- SET_THRST
	remote_send(CMD_SET_THRST, 16'h0AAA);
    quad_decode_wait(); // wait for quad to process
	remote_resp_wait();
	remote_assertresp(RESP_POS_ACK);
	assert (thrst === 9'h0AA)
	else $fatal(1, "[!] thrst assert failed (is %h), should be %h", thrst, 9'h0AA);
	
	// -- EMER_LAND
	remote_send(CMD_EMER_LAND, 16'h0000);
    quad_decode_wait(); // wait for quad to process
	remote_resp_wait();
	remote_assertresp(RESP_POS_ACK);
	assert (thrst === 9'h00 && d_ptch === 16'h0000 && d_roll === 16'h0000 && d_yaw === 16'h0000)
	else $fatal(1, "[!] emergency land assert failed. thrst, roll, yaw, or pitch are nonzero.");
	
	// -- MTRS_OFF
	remote_send(CMD_MTRS_OFF, 16'hxxxx);
    quad_decode_wait(); // wait for quad to process
	remote_resp_wait();
	remote_assertresp(RESP_POS_ACK);
	assert (motors_off === 1'b1)
	else $fatal(1, "[!] motors_off assert failed (is %h), should be %h", motors_off, 1'h1);
	
	// Send another cmd to pass time
	// Check that motors_off is high after as well
	remote_send(CMD_SET_ROLL, 16'hAAAA);
    quad_decode_wait(); // wait for quad to process
	remote_resp_wait();
	remote_assertresp(RESP_POS_ACK);
	assert (motors_off === 1'b1)
	else $fatal(1, "[!] motors_off assert failed, should be high until calibrated");
	
	// Send a calibrate cmd
	remote_send(CMD_CALIBRATE, 16'hxxxx);
	remote_resp_wait();
	remote_assertresp(RESP_POS_ACK);
	
	// Check that motors_off is low after calibrated
	assert (motors_off === 1'b0)
	else $fatal(1, "[!] motors_off assert failed (is %h), should be %h", motors_off, 1'h1);
	
	$display("Test passed!");
	$stop();
	
  end
endmodule
