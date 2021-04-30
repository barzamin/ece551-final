`default_nettype none
/*------------------------------------------------------------------------------
--  This testbench ensures that after the motors off command is sent, the 
--  QuadCopter keeps the motors off until a calibration command is sent
--
--  Team: MEI
--  Authors:
--    * Mitchell Kitzinger
--    * Erin Marshall
--    * Isaac Colbert
--  Term: Spring 2021
------------------------------------------------------------------------------*/
module QuadCopter_Mtrs_Off_tb();
  // Instantiate the shared testbench.
  QuadCopter_tb_shared TB();
  
  initial begin
    // Wait for the shared testbench to be ready
	@(posedge TB.TB_ready);
	
	// Send the initial calibrate command
	TB.remote_send(TB.CALIBRATE, 16'h0000);
	TB.await_response();
	
	// Send the motors_off command
	TB.remote_send(TB.MOTORS_OFF, 16'hxxxx);
	TB.await_response();
	
	// Check the QuadCopter after motors_off cmd
	assert(TB.iDUT.iCMD.motors_off === 1'b1)
	else $fatal(1,"[!] motors_off was not high after motors_off cmd");
	
	// Send a non-calibration cmd
	TB.remote_send(TB.SET_PITCH, 16'h0100);
	TB.await_response();
	
	// Check the QuadCopter again
	assert(TB.iDUT.iCMD.motors_off === 1'b1)
	else $fatal(1,"[!] motors_off was not still high after a cmd that was not calibrate");
	
	// Send the calibrate cmd
	TB.remote_send(TB.CALIBRATE, 16'h0000);
	TB.await_response();
	
	// Check that motors_off is high
	assert (TB.iDUT.motors_off === 1'b0)
	else $fatal(1, "[!] motors_off is still high after calibration");
	
	$display("Test complete");
	$stop();
	
  end
endmodule