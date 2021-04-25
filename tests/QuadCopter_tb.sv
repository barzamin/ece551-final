`default_nettype none
module QuadCopter_tb();

//// Interconnects to DUT/support defined as type wire /////
wire SS_n, SCLK, MOSI, MISO, INT;
wire RX,TX;
wire [7:0] resp;                // response from DUT
wire cmd_sent, resp_rdy;
wire frnt_ESC, back_ESC, left_ESC, rght_ESC;

////// Stimulus is declared as type reg ///////
reg clk, RST_n;
reg [7:0] host_cmd;             // command host is sending to DUT
reg [15:0] data;                // data associated with command
reg send_cmd;                   // asserted to initiate sending of command
reg clr_resp_rdy;               // asserted to knock down resp_rdy

wire [7:0] LED;

//// localparams for command encoding ///
localparam SET_PITCH 	= 8'h02;
localparam SET_ROLL 	= 8'h03;
localparam SET_YAW		= 8'h04;
localparam SET_THRST	= 8'h05;
localparam CALIBRATE	= 8'h06;
localparam E_LAND		= 8'h07;
localparam MOTORS_OFF	= 8'h08;

////////////////////////////////////////////////////////////////
// Instantiate Physical Model of Copter with Inertial sensor //
//////////////////////////////////////////////////////////////
CycloneIV iQuad(
  .clk(clk),
  .RST_n(RST_n),
  .SS_n(SS_n),
  .SCLK(SCLK),
  .MISO(MISO),
  .MOSI(MOSI),
  .INT(INT),
  .frnt_ESC(frnt_ESC),
  .back_ESC(back_ESC),
  .left_ESC(left_ESC),
  .rght_ESC(rght_ESC)
);

////// Instantiate DUT ////////
QuadCopter iDUT(
  .clk(clk),
  .RST_n(RST_n),
  .SS_n(SS_n),
  .SCLK(SCLK),
  .MOSI(MOSI),
  .MISO(MISO),
  .INT(INT),
  .RX(RX),
  .TX(TX),
  .FRNT(frnt_ESC),
  .BCK(back_ESC),
  .LFT(left_ESC),
  .RGHT(rght_ESC)
);

//// Instantiate Master UART (mimics host commands) //////
RemoteComm iREMOTE(
  .clk(clk),
  .rst_n(RST_n),
  .RX(TX),
  .TX(RX),
    .cmd(host_cmd),
  .data(data),
  .send_cmd(send_cmd),
    .cmd_sent(cmd_sent),
  .resp_rdy(resp_rdy),
  .resp(resp),
  .clr_resp_rdy(clr_resp_rdy)
);

localparam RESP_WAIT_TIMEOUT = 1000000; // cycles
task await_response();
  fork
    begin: resp_timeout
      repeat(RESP_WAIT_TIMEOUT) @(posedge clk);
      $fatal(1, "[!] timeout waiting for `resp` after %d clk cycles", RESP_WAIT_TIMEOUT);
    end
    @(posedge resp_rdy) disable resp_timeout;
  join
endtask

localparam DECODE_WAIT_TIMEOUT = 1000000; // cycles
task quad_decode_wait();
  fork
    begin: decode_timeout
      repeat(DECODE_WAIT_TIMEOUT) @(posedge clk);
      $fatal(1, "[!] timeout waiting for `DUT_clr_cmd_rdy` after %d clk cycles", DECODE_WAIT_TIMEOUT);
    end
    @(posedge DUT.clr_cmd_rdy) disable decode_timeout;
  join
endtask

localparam CALIBRATE_TIMEOUT = 1000;
task remote_send(input logic [7:0] s_cmd, input logic [15:0] s_data);
  // set up command
  @(negedge clk);
  host_cmd = s_cmd;
  data = s_data;

  // strobe send_cmd
  send_cmd = 1;
  @(negedge clk)
  send_cmd = 0;

  // Wait for the cmd to be received
  fork
    begin: CMD_RDY_TIMEOUT
      repeat (1000000) @(posedge clk);
      $fatal(1, "[!] timeout waiting for cmd to be received");
    end
    @(posedge iDUT.cmd_rdy) disable CMD_RDY_TIMEOUT;
  join

  // Test if cmd is CALIBRATE
  if (s_cmd == CALIBRATE) begin
    fork
      begin
        // Wait half a clock before checking inertial_cal
        @(negedge clk);
        assert (iDUT.inertial_cal === 1'b1)
        else $fatal(1, "[!] inertial_cal is not high after sending calibrate cmd.");

        @(posedge DUT.tmr_full) disable CAL_TIMEOUT;
        // Wait half a clock before checking strt_cal and inertial_cal
        @(posedge clk);
        assert (iDUT.strt_cal === 1'b1)
        else $fatal(1, "[!] strt_cal didn't go high after tmr_full came high.");
        assert (iDUT.inertial_cal === 1'b1)
        else $fatal(1, "[!] inertial_cal is not high after tmr_full goes high.");

        // The next period after being high, strt_cal should be low
        @(posedge clk);
        assert (iDUT.strt_cal === 1'b0)
        else $fatal(1, "[!] strt_cal stayed high too long.");
        assert (iDUT.inertial_cal === 1'b1)
        else $fatal(1, "[!] inertial_cal is not high after strt_cal goes low.");

        @(posedge iDUT.cal_done);
        // Check that inertial_cal is low after cal_done goes high
        @(negedge clk);
        assert (iDUT.inertial_cal === 1'b0)
        else $fatal(1, "[!] inertial_cal is not low after cal_done goes high.");
        // Set cal_done back to 0 for later tests
        @(negedge clk);
        @(negedge iDUT.cal_done);
      end
      begin: CAL_TIMEOUT
        repeat(CALIBRATE_TIMEOUT) @(posedge clk);
        $fatal(1, "[!] timeout waiting for `tmr_full` after %d clk cycles", CALIBRATE_TIMEOUT);
      end
    join
  end
endtask

initial begin
  clk = 1'b0;
  RST_n = 1'b0;
  repeat(5) @(negedge clk);
  RST_n = 1'b1;
end

always
  #10 clk = ~clk;

/// perhaps include a tb_tasks file with helper tasks for testing.

endmodule
