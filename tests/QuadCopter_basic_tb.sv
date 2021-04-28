`default_nettype none
/*------------------------------------------------------------------------------
--  This testbench ensures pitch/roll/yaw all converge when set to new values
--  and that they all converge to 0 during an emergency landing.
--
--  Team: MEI
--  Authors:
--    * Mitchell Kitzinger
--    * Erin Marshall
--    * Isaac Colbert
--  Term: Spring 2021
------------------------------------------------------------------------------*/
module QuadCopter_basic_tb();

// Instantiate the shared testbench.
QuadCopter_tb_shared TB();

initial begin
  // Wait for the shared testbench to be ready.
  @(posedge TB.TB_ready);

  // CALIBRATE
  TB.remote_send(TB.CALIBRATE, 16'h0);
  TB.await_response();

  // THRUST
  TB.remote_send(TB.SET_THRST, 16'h00AA);
  TB.await_response();
  TB.thrust_check(TB.SET_THRST, 16'h00AA);

  // PITCH/YAW/ROLL
  TB.remote_send(TB.SET_PITCH, 16'h00AA);
  TB.await_response();
  TB.remote_send(TB.SET_YAW, 16'h0099);
  TB.await_response();
  TB.remote_send(TB.SET_ROLL, 16'h0066);
  TB.await_response();
  fork
    TB.convergence_check(TB.SET_PITCH, 16'h00AA);
    TB.convergence_check(TB.SET_YAW, 16'h0099);
    TB.convergence_check(TB.SET_ROLL, 16'h0066);
  join

  TB.remote_send(TB.E_LAND, 16'h0000);
  TB.await_response();
  TB.convergence_check(TB.E_LAND, 16'h0000);
  $finish();
end
endmodule