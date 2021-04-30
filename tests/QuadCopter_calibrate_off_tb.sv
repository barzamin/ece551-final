`default_nettype none
/*------------------------------------------------------------------------------
--  This testbench cycles the QuadCopter through resets, calibrates,
--  and motor off commands.
--
--  Team: MEI
--  Authors:
--    * Mitchell Kitzinger
--    * Erin Marshall
--    * Isaac Colbert
--  Term: Spring 2021
------------------------------------------------------------------------------*/
module QuadCopter_calibrate_off_tb();

QuadCopter_tb_shared TB();

initial begin
  // Shared TB is ready.
  @(posedge TB.TB_ready);

  // Calibrate the copter.
  TB.remote_send(TB.CALIBRATE, 16'h0);
  TB.await_response();

  // Set the yaw.
  TB.remote_send(TB.SET_YAW, 16'h0100);
  TB.await_response();

  // A while latter send motors off command.
  repeat(1000) @(posedge TB.clk);
  TB.remote_send(TB.MOTORS_OFF, 16'h0);
  TB.await_response();

  assert(TB.iDUT.motors_off === 1'b1)
  else $fatal(1,"[!] motors_off was not high after motors off cmd");

  // Calibrate.
  TB.remote_send(TB.CALIBRATE, 16'h0);
  TB.await_response();

  // Check that calibration worked.
  repeat(1000) @(posedge TB.clk);
  assert(TB.iDUT.motors_off === 1'b0)
  else $fatal(1,"[!] motors_off was not low after calibrate cmd");

  // Set the yaw.
  TB.remote_send(TB.SET_YAW, 16'h0050);
  TB.await_response();

  // Perform a reset.
  @(negedge TB.clk);
  TB.RST_n = 1'b0;
  @(negedge TB.clk);
  TB.RST_n = 1'b1;
  
  // Check that reset forced motors_off to be high.
  assert(TB.iDUT.motors_off === 1'b1)
  else $fatal(1,"[!] motors_off was not high after reset");

  $finish();
end
endmodule