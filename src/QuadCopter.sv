`default_nettype none
/*------------------------------------------------------------------------------
--  Top-level module for the quadrotor controller design.
--
--  Team: MEI
--  Authors:
--    * Mitchell Kitzinger
--    * Erin Marshall
--    * Isaac Colbert
--  Term: Spring 2021
------------------------------------------------------------------------------*/
module QuadCopter(
  input wire clk,   // 50MHz clock
  input wire RST_n, // Reset from push button

  input wire RX,    // command from BLE interface
  input wire MISO,  // response from inertial sensor
  input wire INT,   // Interrupt pin from inertial

  output wire SS_n, // serf select to inertial sensor
  output wire SCLK, // SCLK to inertial sensor
  output wire MOSI, // MOSI to inertial sensor
  output wire TX,   // TX to BLE interface

  output wire FRNT, // front motor PWM
  output wire BCK,  // back motor PWM
  output wire LFT,  // left motor PWM
  output wire RGHT  // right motor PWM
);
  /*------------------------------------------------------------------------------
  --  Internal interconnecting signals
  ------------------------------------------------------------------------------*/
  wire cmd_rdy;         // command from wireless ready
  wire [7:0] cmd;       // 8-bit command from wireless
  wire [15:0] data;     // 16-bit data from wireless
  wire clr_cmd_rdy;     // clear the command from wireless
  wire [7:0] resp;      // response to wireless
  wire send_resp;       // asserted to send response to wireless
  wire resp_sent;       // indicates response to wireless has been sent

  wire vld;                  // goes high one clock cycle when new inertial measurement
  wire signed [15:0] ptch;   // current pitch
  wire signed [15:0] roll;   // current roll
  wire signed [15:0] yaw;    // current yaw
  wire signed [15:0] d_ptch; // desired pitch
  wire signed [15:0] d_roll; // desired roll
  wire signed [15:0] d_yaw;  // desired yaw

  wire [8:0] thrst;  // desired thrust
  wire rst_n;        // internal synchronized global reset
  wire strt_cal;     // from cmd_cfg to inertial_intf
  wire inertial_cal; // indicates calibration in progress to flght_control
  wire motors_off;   // to flight control, forces motors off
  wire cal_done;     // from inertial_intf to cmd_cfg

  wire [10:0] frnt_spd; // front motor speed from flght_cntrl
  wire [10:0] bck_spd;  // front motor speed from flght_cntrl
  wire [10:0] lft_spd;  // front motor speed from flght_cntrl
  wire [10:0] rght_spd; // front motor speed from flght_cntrl

  `ifdef DC // Design Compiler sets DC
    localparam FAST_SIM = 0; // synthesize the full thing
  `elsif
    localparam FAST_SIM = 1; // used to accelerate simulations.
  `endif

  /*------------------------------------------------------------------------------
  --  UART_comm block: handling quad <-> host BLE communication
  ------------------------------------------------------------------------------*/
  UART_comm iCOMM(
    .clk(clk),
    .rst_n(rst_n),

    .RX(RX),
    .TX(TX),

    .resp(resp),
    .send_resp(send_resp),
    .resp_sent(),
    .cmd_rdy(cmd_rdy),
    .cmd(cmd),
    .data(data),
    .clr_cmd_rdy(clr_cmd_rdy)
  );

  /*------------------------------------------------------------------------------
  --  cmd_config block: parse and decodecommands from remote
  ------------------------------------------------------------------------------*/
  cmd_cfg #(FAST_SIM) iCMD(
    .clk(clk),
    .rst_n(rst_n),

    .cmd_rdy(cmd_rdy),
    .cmd(cmd),
    .data(data),
    .clr_cmd_rdy(clr_cmd_rdy),
    .resp(resp),
    .send_resp(send_resp),
    .d_ptch(d_ptch),
    .d_roll(d_roll),
    .d_yaw(d_yaw),
    .thrst(thrst),
    .strt_cal(strt_cal),
    .inertial_cal(inertial_cal),
    .motors_off(motors_off),
    .cal_done(cal_done)
  );

  /*------------------------------------------------------------------------------
  --  inert_intf block: handle communication with NEMO IMU
  ------------------------------------------------------------------------------*/
  inert_intf #(FAST_SIM) iNEMO(
    .clk(clk),
    .rst_n(rst_n),

    .ptch(ptch),
    .roll(roll),
    .yaw(yaw),
    .strt_cal(strt_cal),
    .cal_done(cal_done),
    .vld(vld),

    .SS_n(SS_n),
    .SCLK(SCLK),
    .MOSI(MOSI),
    .MISO(MISO),
    .INT(INT)
  );

  /*------------------------------------------------------------------------------
  --  flght_cntrl block: run flight control loops
  ------------------------------------------------------------------------------*/
  flght_cntrl_pipeline ifly(
    .clk(clk),
    .rst_n(rst_n),

    .vld(vld),
    .d_ptch(d_ptch),
    .d_roll(d_roll),
    .d_yaw(d_yaw),
    .ptch(ptch),
    .roll(roll),
    .yaw(yaw),
    .thrst(thrst),
    .inertial_cal(inertial_cal),
    .frnt_spd(frnt_spd),
    .bck_spd(bck_spd),
    .lft_spd(lft_spd),
    .rght_spd(rght_spd)
  );


  /*------------------------------------------------------------------------------
  --  ESCs: ESC PWM interface block for all motors
  ------------------------------------------------------------------------------*/
  ESCs iESC (
    .clk(clk),
    .rst_n(rst_n),

    .frnt_spd(frnt_spd),
    .bck_spd(bck_spd),
    .lft_spd(lft_spd),
    .rght_spd(rght_spd),

    .wrt(vld),
    .motors_off(motors_off),

    .frnt(FRNT),
    .bck(BCK),
    .lft(LFT),
    .rght(RGHT)
  );


  /*------------------------------------------------------------------------------
  --  Global reset synchronizer
  ------------------------------------------------------------------------------*/
  reset_synch iRST (.clk(clk), .RST_n(RST_n), .rst_n(rst_n));
endmodule
