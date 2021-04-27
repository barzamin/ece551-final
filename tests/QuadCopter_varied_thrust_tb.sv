`default_nettype none
/*------------------------------------------------------------------------------
--  This testbench measures the time it takes for pitch/roll/yaw to converge
--  to a new value at one thrust level, then checks that at 
--  a higher thrust levels the time to converge is smaller.
--
--  Team: MEI
--  Authors:
--    * Mitchell Kitzinger
--    * Erin Marshall
--    * Isaac Colbert
--  Term: Spring 2021
------------------------------------------------------------------------------*/
module QuadCopter_varied_thrust_tb();

// Instantiate the shared testbench.
QuadCopter_tb_shared TB();

realtime start_time, slow_converge_time, fast_converge_time;

initial begin
  // Shared TB is ready.
  @(posedge TB.TB_ready);

  // Calibrate the copter.
  TB.remote_send(TB.CALIBRATE, 16'h0);
  TB.await_response();

  // Set the thrust to a low value.
  TB.remote_send(TB.SET_THRST, 16'h0005);
  TB.await_response();

  // Set the yaw to a new value and time how long it takes to converge.
  TB.remote_send(TB.SET_YAW, 16'h00AA);
  TB.await_response();
  start_time = $realtime;
  TB.convergence_check(TB.SET_YAW, 16'h00AA);
  slow_converge_time = $realtime - start_time;

  // Zero out the yaw.
  TB.remote_send(TB.SET_YAW, 16'h0);
  TB.await_response();
  TB.convergence_check(TB.SET_YAW, 16'h0);

  // Significantly increase thrust.
  TB.remote_send(TB.SET_THRST, 16'h0050);
  TB.await_response();

  // Set the yaw to the same previous value and measure convergence time.
  TB.remote_send(TB.SET_YAW, 16'h00AA);
  TB.await_response();
  start_time = $realtime;
  TB.convergence_check(TB.SET_YAW, 16'h00AA);
  fast_converge_time = $realtime - start_time;
  assert(fast_converge_time < slow_converge_time)
  else $fatal(1, "[!] took longer to converge with more thrust. fast_converge_time = %d, slow_converge_time = %d", fast_converge_time, slow_converge_time);
  $finish();
end
endmodule