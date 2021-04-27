`default_nettype none
/*------------------------------------------------------------------------------
--  A shared testbench that can be used by other testbenches to test 
--  the design of QuadCopter.sv.
--
--  Team: MEI
--  Authors:
--    * Mitchell Kitzinger
--    * Erin Marshall
--    * Isaac Colbert
--  Term: Spring 2021
------------------------------------------------------------------------------*/
module QuadCopter_tb_shared();

// Interconnects to DUT/support defined as type wire
wire SS_n, SCLK, MOSI, MISO, INT;
wire RX,TX;
wire [7:0] resp;                // response from DUT
wire cmd_sent, resp_rdy;
wire frnt_ESC, back_ESC, left_ESC, rght_ESC;

// Stimulus is declared as type reg
reg clk, RST_n;
reg [7:0] host_cmd;             // command host is sending to DUT
reg [15:0] data;                // data associated with command
reg send_cmd;                   // asserted to initiate sending of command
reg clr_resp_rdy;               // asserted to knock down resp_rdy

// Parameters for command encoding
localparam SET_PITCH 	= 8'h02;
localparam SET_ROLL 	= 8'h03;
localparam SET_YAW		= 8'h04;
localparam SET_THRST	= 8'h05;
localparam CALIBRATE	= 8'h06;
localparam E_LAND		  = 8'h07;
localparam MOTORS_OFF	= 8'h08;

// Parameters for timeouts and convergence margin.
localparam RESP_WAIT_TIMEOUT_CYCLES  = 1000000;
localparam CALIBRATE_TIMEOUT_CYCLES  = 1000;
localparam CMD_RDY_TIMEOUT_CYCLES    = 1000000;
localparam CONVERGENCE_PERIOD_CYCLES = 20000000; // 20000000 * 10 ps = 200mil PS
localparam CONVERGENCE_MARGIN        = 10;

// Convergence signals
logic ptch_converge, roll_converge, yaw_converge;

// Signals that the this TB is ready to begin.
logic TB_ready;

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

////////////////////////////////
////// Instantiate DUT ////////
//////////////////////////////
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

///////////////////////////////////////////////////////////
//// Instantiate Master UART (mimics host commands) //////
/////////////////////////////////////////////////////////
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

// If the desired pitch/roll/yaw are within CONVERGENCE_MARGIN of 
// the actual value these go high
assign ptch_converge = (abs(iDUT.ptch - data) < CONVERGENCE_MARGIN) ? 1'b1 : 1'b0;
assign roll_converge = (abs(iDUT.roll - data) < CONVERGENCE_MARGIN) ? 1'b1 : 1'b0;
assign yaw_converge = (abs(iDUT.yaw - data) < CONVERGENCE_MARGIN) ? 1'b1 : 1'b0;

// This task waits RESP_WAIT_TIMEOUT_CYCLES before timing out.
// If a response is recieved, it checks to make sure it's the expected response.
task await_response();
  fork
    begin: resp_timeout
      repeat(RESP_WAIT_TIMEOUT_CYCLES) @(posedge clk);
      $fatal(1, "[!] timeout waiting for `resp` after %d clk cycles", RESP_WAIT_TIMEOUT_CYCLES);
    end
    begin
      @(posedge resp_rdy) disable resp_timeout;
      assert(resp === 8'hA5)
      else begin
        $fatal(1, "[!] invalid response recieved. resp = %d", resp);
      end
      @(negedge clk) clr_resp_rdy = 1'b1;
      @(negedge clk) clr_resp_rdy = 1'b0;
    end
  join
endtask

// This task sends commands and data to the DUT.
// It also performs checks if the command is CALIBRATE.
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
      repeat (CMD_RDY_TIMEOUT_CYCLES) @(posedge clk);
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

        @(posedge iDUT.iCMD.tmr_full) disable CAL_TIMEOUT;
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
      end
      begin: CAL_TIMEOUT
        repeat(CALIBRATE_TIMEOUT_CYCLES) @(posedge clk);
        $fatal(1, "[!] timeout waiting for `tmr_full` after %d clk cycles", CALIBRATE_TIMEOUT_CYCLES);
      end
    join
  end
endtask

// This task waits CONVERGENCE_PERIOD_CYCLES before timing out.
// If the signal converges properly it finishes. Checks pitch/roll/yaw for E_LAND.
task convergence_check(input logic [7:0] s_cmd, input logic [15:0] s_data);
  fork
    // If the corresponding convergence signals haven't gone high by now, test failed.
	begin: converge_timeout
        repeat(CONVERGENCE_PERIOD_CYCLES) @(posedge clk);
        case(s_cmd)
            SET_PITCH:
            $fatal(1, "[!] iDUT.ptch failed to converge to %d in %d clk cycles. iDUT.ptch = %d", s_data, CONVERGENCE_PERIOD_CYCLES, iDUT.ptch);
            SET_ROLL:
            $fatal(1, "[!] iDUT.roll failed to converge to %d in %d clk cycles. iDUT.roll = %d", s_data, CONVERGENCE_PERIOD_CYCLES, iDUT.roll);
            SET_YAW:
            $fatal(1, "[!] iDUT.yaw failed to converge to %d in %d clk cycles. iDUT.yaw = %d", s_data, CONVERGENCE_PERIOD_CYCLES, iDUT.yaw);
        // For E_LAND, pitch/roll/yaw should all converge to 0.
            E_LAND: begin
            assert(abs(iDUT.ptch) < CONVERGENCE_MARGIN)
            else $error("[!] iDUT.ptch failed to converge to 0 in %d clk cycles. iDUT.ptch = %d", CONVERGENCE_PERIOD_CYCLES, iDUT.ptch);
            assert(abs(iDUT.roll) < CONVERGENCE_MARGIN)
            else $error("[!] iDUT.roll failed to converge to 0 in %d clk cycles. iDUT.roll = %d", CONVERGENCE_PERIOD_CYCLES, iDUT.roll);
            assert(abs(iDUT.yaw) < CONVERGENCE_MARGIN)
            else $error("[!] iDUT.yaw failed to converge to 0 in %d clk cycles. iDUT.yaw = %d", CONVERGENCE_PERIOD_CYCLES, iDUT.yaw);
        end
        endcase
		  $fatal(1, "[!] E_LAND cmd failed.");
	end
	begin
    // When the corresponding convergence signals go high we can disable the timeout.
	  case(s_cmd)
      SET_PITCH:
        @(posedge ptch_converge);
      SET_ROLL:
        @(posedge roll_converge);
      SET_YAW:
        @(posedge yaw_converge);
      E_LAND:
        fork
          @(posedge ptch_converge);
          @(posedge roll_converge);
          @(posedge yaw_converge);
        join
	  endcase
	  disable converge_timeout;
	end
  join
endtask

// This task ensure the DUTs thrust value is properly updated.
task thrust_check(input logic [7:0] s_cmd, input logic [15:0] s_data);
  if(s_cmd == SET_THRST && iDUT.thrst !== {s_data[8:0]})
    $fatal(1, "[!] iDUT.thrst failed to update to %d. iDUT.thrst = %d", s_data[8:0], iDUT.thrst);
endtask

// Takes the absolute value of the provided value.
function [15:0] abs(input signed [15:0] value);
  if (value < 0)
    abs = -value;
  else
    abs = value;
endfunction

initial begin
  // Initial setup and reset.
  clk = 1'b0;
  RST_n = 1'b0;

  send_cmd = 1'b0;
  clr_resp_rdy = 1'b0;
  host_cmd = 8'b0;
  data = 16'b0;

  repeat(2) @(negedge clk);
  RST_n = 1'b1;

  // Let the main testbench begin.
  TB_ready = 1'b1;
end

always
  #10 clk = ~clk;

endmodule