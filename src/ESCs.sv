module ESCs(clk, rst_n, frnt_spd, bck_spd, lft_spd, rght_spd, motors_off,
        wrt, frnt, bck, lft, rght);

  input clk, rst_n;

  input [10:0] frnt_spd;			// speed of front motor from PD_math
  input [10:0] bck_spd;			// speed of back motor from PD_math
  input [10:0] lft_spd;			// speed of left motor from PD_math
  input [10:0] rght_spd;			// speed of right motor from PD_math

  input motors_off;				// signal to turn off motors from cmd_cnfg
  input wrt;						// wrt signal for ESC_interfaces from ?????
                  // vld from inert_intf?
                  // wouldn't vld start the pulse with different data

  output frnt;					// PWM pulse sent to front motor
  output bck;						// PWM pulse sent to back motor
  output lft;						// PWM pulse sent to left motor
  output rght;					// PWM pulse sent to right motor

  // Internal signals
  logic [10:0] frnt_cmd, bck_cmd, lft_cmd, rght_cmd;

  // Instantiations of ESC_interfaces
  ESC_interface_pipeline frntESC(.clk(clk), .rst_n(rst_n), .wrt(wrt),
              .SPEED(frnt_cmd), .PWM(frnt));

  ESC_interface_pipeline bckESC(.clk(clk), .rst_n(rst_n), .wrt(wrt),
              .SPEED(bck_cmd), .PWM(bck));

  ESC_interface_pipeline lftESC(.clk(clk), .rst_n(rst_n), .wrt(wrt),
              .SPEED(lft_cmd), .PWM(lft));

  ESC_interface_pipeline rghtESC(.clk(clk), .rst_n(rst_n), .wrt(wrt),
              .SPEED(rght_cmd), .PWM(rght));

  // Muxes to select between spd inputs and 11'h0000 depending on
  // if motors_off is asserted
  assign frnt_cmd = (motors_off) ? 11'h000 : frnt_spd;
  assign bck_cmd = (motors_off) ? 11'h000 : bck_spd;
  assign lft_cmd = (motors_off) ? 11'h000 : lft_spd;
  assign rght_cmd = (motors_off) ? 11'h000 : rght_spd;

endmodule