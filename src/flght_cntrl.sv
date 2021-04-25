module flght_cntrl(clk,rst_n,vld,inertial_cal,d_ptch,d_roll,d_yaw,ptch,
          roll,yaw,thrst,frnt_spd,bck_spd,lft_spd,rght_spd);

input clk,rst_n;
input vld;									// tells when a new valid inertial reading ready
                      // only update D_QUEUE on vld readings
input inertial_cal;							// need to run motors at CAL_SPEED during inertial calibration
input signed [15:0] d_ptch,d_roll,d_yaw;	// desired pitch roll and yaw (from cmd_cfg)
input signed [15:0] ptch,roll,yaw;			// actual pitch roll and yaw (from inertial interface)
input [8:0] thrst;							// thrust level from slider
output [10:0] frnt_spd;						// 11-bit unsigned speed at which to run front motor
output [10:0] bck_spd;						// 11-bit unsigned speed at which to back front motor
output [10:0] lft_spd;						// 11-bit unsigned speed at which to left front motor
output [10:0] rght_spd;						// 11-bit unsigned speed at which to right front motor


  //////////////////////////////////////////////////////
  // You will need a bunch of interal wires declared //
  // for intermediate math results...do that here   //
  ///////////////////////////////////////////////////
  wire [9:0] ptch_pterm, roll_pterm, yaw_pterm;
  wire [11:0] ptch_dterm, roll_dterm, yaw_dterm;
  wire [12:0] ptch_13_dterm, ptch_13_pterm, yaw_13_dterm, yaw_13_pterm;
  wire [12:0] roll_13_dterm, roll_13_pterm, thrst_13;
  wire [12:0] frnt_sum,bck_sum,lft_sum,rght_sum;
  wire [10:0] frnt_sat,bck_sat,lft_sat,rght_sat;

  ///////////////////////////////////////////////////////////////
  // some Parameters to keep things more generic and flexible //
  /////////////////////////////////////////////////////////////
  localparam CAL_SPEED = 11'h290;		// speed to run motors at during inertial calibration
  localparam MIN_RUN_SPEED = 13'h2C0;	// minimum speed while running
  localparam D_COEFF = 5'b00111;		// D coefficient in PID control = +7

  //////////////////////////////////////
  // Instantiate 3 copies of PD_math //
  ////////////////////////////////////
  PD_math iPTCH(.clk(clk),.rst_n(rst_n),.vld(vld),.desired(d_ptch),.actual(ptch),.pterm(ptch_pterm),.dterm(ptch_dterm));
  PD_math iROLL(.clk(clk),.rst_n(rst_n),.vld(vld),.desired(d_roll),.actual(roll),.pterm(roll_pterm),.dterm(roll_dterm));
  PD_math iYAW(.clk(clk),.rst_n(rst_n),.vld(vld),.desired(d_yaw),.actual(yaw),.pterm(yaw_pterm),.dterm(yaw_dterm));

  // Sign extend all pterms and dterms to 13 bits
  assign ptch_13_dterm = {ptch_dterm[11],ptch_dterm[11:0]};
  assign ptch_13_pterm = {{3{ptch_pterm[9]}},ptch_pterm[9:0]};
  assign roll_13_dterm = {roll_dterm[11],roll_dterm[11:0]};
  assign roll_13_pterm = {{3{roll_pterm[9]}},roll_pterm[9:0]};
  assign yaw_13_dterm = {yaw_dterm[11],yaw_dterm[11:0]};
  assign yaw_13_pterm = {{3{yaw_pterm[9]}},yaw_pterm[9:0]};

  // zero-extend thrust to 13 bits (unsigned number)
  assign thrst_13 = {4'b0000,thrst[8:0]};

  // calculate each of the motor 13-bit results
  assign frnt_sum = MIN_RUN_SPEED + thrst_13 - ptch_13_pterm - ptch_13_dterm - yaw_13_pterm - yaw_13_dterm;
  assign bck_sum = MIN_RUN_SPEED + thrst_13 + ptch_13_pterm + ptch_13_dterm - yaw_13_pterm - yaw_13_dterm;
  assign lft_sum = MIN_RUN_SPEED + thrst_13 - roll_13_pterm - roll_13_dterm + yaw_13_pterm + yaw_13_dterm;
  assign rght_sum = MIN_RUN_SPEED + thrst_13 + roll_13_pterm + roll_13_dterm + yaw_13_pterm + yaw_13_dterm;

  // Saturate each sum to 11-bits (unsigned)
  assign frnt_sat = (|frnt_sum[12:11]) ? 11'h7ff : frnt_sum[10:0];
  assign bck_sat = (|bck_sum[12:11]) ? 11'h7ff : bck_sum[10:0];
  assign lft_sat = (|lft_sum[12:11]) ? 11'h7ff : lft_sum[10:0];
  assign rght_sat = (|rght_sum[12:11]) ? 11'h7ff : rght_sum[10:0];

  // Select between CAL_SPEED and motor result depending on calibrating or not
  assign frnt_spd = (inertial_cal) ? CAL_SPEED : frnt_sat;
  assign bck_spd = (inertial_cal) ? CAL_SPEED : bck_sat;
  assign lft_spd = (inertial_cal) ? CAL_SPEED : lft_sat;
  assign rght_spd = (inertial_cal) ? CAL_SPEED : rght_sat;


endmodule
