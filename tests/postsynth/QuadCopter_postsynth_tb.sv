`timescale 1ns/1ps
`default_nettype none
/*------------------------------------------------------------------------------
--  This is a simplified post-synthesis testbench for QuadCopter
--  that simply sends a single thrust command and waits for a response.
--
--  Team: MEI
--  Authors:
--    * Mitchell Kitzinger
--    * Erin Marshall
--    * Isaac Colbert
--  Term: Spring 2021
------------------------------------------------------------------------------*/
module QuadCopter_postsynth_tb();

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
  localparam RESP_POS_ACK   = 8'ha5;

  // timeouts
  localparam RESP_WAIT_TIMEOUT_CYCLES  = 1000000;

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

  task remote_send(input logic [7:0] s_cmd, input logic [15:0] s_data);
    // set up command
    @(negedge clk);
    host_cmd = s_cmd;
    data = s_data;

    // strobe send_cmd
    send_cmd = 1;
    @(negedge clk)
    send_cmd = 0;
  endtask

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

    remote_send(SET_THRST, 16'h0666);
    await_response();

    $finish();
  end

  always
    #10 clk = ~clk;
endmodule