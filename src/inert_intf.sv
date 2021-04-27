/*------------------------------------------------------------------------------
--  Interface to the ST iNEMO IMU. Acts as a SPI monarch; drives commands to the
--  IMU in a loop to obtain accelerometer and gyroscope data, passing it to an
--  inertial_intergator sensor fusion loop which gives final (pitch,roll,yaw).
--
--  Team: MEI
--  Authors:
--    * Mitchell Kitzinger
--    * Erin Marshall
--    * Isaac Colbert
--  Term: Spring 2021
------------------------------------------------------------------------------*/
module inert_intf
#(parameter FAST_SIM = 1)
(
  input clk, rst_n, // global clock and active-low asynch reset
  input MISO,       // SPI input from inertial sensor
  input INT,        // goes high when measurement ready
  input strt_cal,   // from comand config.  Indicates we should start calibration

  output signed [15:0] ptch,roll,yaw, // fusion corrected angles
  output cal_done,                    // indicates calibration is done
  output reg vld,                     // goes high for 1 clock when new outputs available
  output SS_n,SCLK,MOSI               // SPI outputs
);

  // Internal signals
  logic INT_1, INT_2;
  logic [15:0] cnt;
  reg[15:0] ptch_reg, roll_reg, yaw_reg, ax_reg, ay_reg;

  //////////////////////////////////////
  // Outputs of SM are of type logic //
  ////////////////////////////////////
  logic cpt_ax_h, cpt_ax_l;
  logic cpt_ay_h, cpt_ay_l;
  logic cpt_ptch_h, cpt_ptch_l;
  logic cpt_roll_h, cpt_roll_l;
  logic cpt_yaw_h, cpt_yaw_l;
  logic wrt;
  logic [15:0] cmd, inert_data;

  //////////////////////////////////////////////////////////////
  // Declare any needed internal signals that connect blocks //
  ////////////////////////////////////////////////////////////
  wire signed [15:0] ptch_rt,roll_rt,yaw_rt; // feeds inertial_integrator
  wire signed [15:0] ax,ay; // accel data to inertial_integrator

  ////////////////////////////////////////////////////////////
  // Instantiate SPI monarch for Inertial Sensor interface //
  //////////////////////////////////////////////////////////
  SPI_mnrch iSPI(.clk(clk),.rst_n(rst_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),.MOSI(MOSI),
                 .wrt(wrt),.done(done),.rd_data(inert_data),.wt_data(cmd));

  ////////////////////////////////////////////////////////////////////
  // Instantiate Angle Engine that takes in angular rate readings  //
  // and acceleration info and produces ptch,roll, & yaw readings //
  /////////////////////////////////////////////////////////////////
  inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal), .cal_done(cal_done),
                                       .vld(vld), .ptch_rt(ptch_rt), .roll_rt(roll_rt), .yaw_rt(yaw_rt), .ax(ax),
                           .ay(ay), .ptch(ptch), .roll(roll), .yaw(yaw));

  ////////////////////////////////////////////
  // Declare any needed internal registers //
  //////////////////////////////////////////

  // Double flop for INT
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      INT_1 <= 1'b0;
      INT_2 <= 1'b0;
    end else begin
      INT_1 <= INT;
      INT_2 <= INT_1;
    end
  end

  // 16-bit counter for initialization
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      cnt <= 16'h0000;
    end else begin
      cnt <= cnt + 1;
    end
  end

  // Holding registers
  // ptch holding register
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      ptch_reg <= 16'h00;
    else if (cpt_ptch_h)
      ptch_reg[15:8] <= inert_data[7:0];
    else if (cpt_ptch_l)
      ptch_reg[7:0] <= inert_data[7:0];
  end
  // assign wire to inertial_integrator as ptch_reg
  assign ptch_rt = ptch_reg;

  // roll holding register
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      roll_reg <= 16'h00;
    else if (cpt_roll_h)
      roll_reg[15:8] <= inert_data[7:0];
    else if (cpt_roll_l)
      roll_reg[7:0] <= inert_data[7:0];
  end
  // assign wire to inertial_integrator as roll_reg
  assign roll_rt = roll_reg;

  // yaw holding register
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      yaw_reg <= 16'h00;
    else if (cpt_yaw_h)
      yaw_reg[15:8] <= inert_data[7:0];
    else if (cpt_yaw_l)
      yaw_reg[7:0] <= inert_data[7:0];
  end
  // assign wire to inertial_integrator as yaw_reg
  assign yaw_rt = yaw_reg;

  // ax holding register
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      ax_reg <= 16'h00;
    else if (cpt_ax_h)
      ax_reg[15:8] <= inert_data[7:0];
    else if (cpt_ax_l)
      ax_reg[7:0] <= inert_data[7:0];
  end
  // assign wire to inertial_integrator as ax_reg
  assign ax = ax_reg;

  // ay holding register
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      ay_reg <= 16'h00;
    else if (cpt_ay_h)
      ay_reg[15:8] <= inert_data[7:0];
    else if (cpt_ay_l)
      ay_reg[7:0] <= inert_data[7:0];
  end
  // assign wire to inertial_integrator as ay_reg
  assign ay = ay_reg;

  ///////////////////////////////////////
  // Create enumerated type for state //
  /////////////////////////////////////
  typedef enum reg[3:0] {INIT1, INIT2, INIT3, INIT4, WAIT_DATA, PTCH_L, PTCH_H,
              ROLL_L, ROLL_H, YAW_L, YAW_H, AX_L, AX_H, AY_L, AY_H} state_t;
  state_t state, nxt_state;

  // State flop
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      state <= INIT1;
    else
      state <= nxt_state;
  end

  // Output and transition logic
  always_comb begin
    //// Default Outputs ////
    cmd = 16'h0000;
    wrt = 1'b0;
    vld = 1'b0;
    cpt_ax_h = 1'b0;
    cpt_ax_l = 1'b0;
    cpt_ay_h = 1'b0;
    cpt_ay_l = 1'b0;
    cpt_ptch_h = 1'b0;
    cpt_ptch_l = 1'b0;
    cpt_roll_h = 1'b0;
    cpt_roll_l = 1'b0;
    cpt_yaw_h = 1'b0;
    cpt_yaw_l = 1'b0;
    nxt_state = state;

    case (state)
      INIT2: begin
        cmd = 16'h1062;
        if (done) begin
          wrt = 1'b1;
          nxt_state = INIT3;
        end
      end
      INIT3: begin
        cmd = 16'h1162;
        if (done) begin
          wrt = 1'b1;
          nxt_state = INIT4;
        end
      end
      INIT4: begin
        cmd = 16'h1460;
        if (done) begin
          wrt = 1'b1;
          nxt_state = WAIT_DATA;
        end
      end
      WAIT_DATA: begin
        if (INT_2) begin
          cmd = 16'hA200;
          wrt = 1'b1;
          nxt_state = PTCH_L;
        end
      end
      PTCH_L: begin
        cmd = 16'hA200;
        // Capture ptch_l, wait till done to go to next state
        cpt_ptch_l = 1'b1;
        if (done) begin
          cmd = 16'hA300;
          wrt = 1'b1;
          nxt_state = PTCH_H;
        end
      end
      PTCH_H: begin
        cmd = 16'hA300;
        // Capture ptch_h, wait till done to go to next state
        cpt_ptch_h = 1'b1;
        if (done) begin
          cmd = 16'hA400;
          wrt = 1'b1;
          nxt_state = ROLL_L;
        end
      end
      ROLL_L: begin
        cmd = 16'hA400;
        // Capture roll_l, wait till done to go to next state
        cpt_roll_l = 1'b1;
        if (done) begin
          cpt_roll_h = 1'b1;
          cmd = 16'hA500;
          wrt = 1'b1;
          nxt_state = ROLL_H;
        end
      end
      ROLL_H: begin
        cmd = 16'hA500;
        // Capture roll_h, wait till done to go to next state
        cpt_roll_h = 1'b1;
        if (done) begin
          cpt_yaw_l = 1'b1;
          cmd = 16'hA600;
          wrt = 1'b1;
          nxt_state = YAW_L;
        end
      end
      YAW_L: begin
        cmd = 16'hA600;
        // Capture yaw_l, wait till done to go to next state
        cpt_yaw_l = 1'b1;
        if (done) begin
          cpt_yaw_h = 1'b1;
          cmd = 16'hA700;
          wrt = 1'b1;
          nxt_state = YAW_H;
        end
      end
      YAW_H: begin
        cmd = 16'hA700;
        // Capture yaw_h, wait till done to go to next state
        cpt_yaw_h = 1'b1;
        if (done) begin
          cpt_ax_l = 1'b1;
          cmd = 16'hA800;
          wrt = 1'b1;
          nxt_state = AX_L;
        end
      end
      AX_L: begin
        cmd = 16'hA800;
        // Capture ax_l, wait till done to go to next state
        cpt_ax_l = 1'b1;
        if (done) begin
          cpt_ax_h = 1'b1;
          cmd = 16'hA900;
          wrt = 1'b1;
          nxt_state = AX_H;
        end
      end
      AX_H: begin
        cmd = 16'hA900;
        // Capture ax_h, wait till done to go to next state
        cpt_ax_h = 1'b1;
        if (done) begin
          cpt_ay_l = 1'b1;
          cmd = 16'hAA00;
          wrt = 1'b1;
          nxt_state = AY_L;
        end
      end
      AY_L: begin
        cmd = 16'hAA00;
        // Capture ay_l, wait till done to go to next state
        cpt_ay_l = 1'b1;
        if (done) begin
          cpt_ay_h = 1'b1;
          cmd = 16'hAB00;
          wrt = 1'b1;
          nxt_state = AY_H;
        end
      end
      AY_H: begin
        cmd = 16'hAB00;
        // Capture ay_h, wait till done to go to next state
        cpt_ay_h = 1'b1;
        if (done) begin
          vld = 1'b1;
          nxt_state = WAIT_DATA;
        end
      end
      default: begin
        //// Default state: INIT1 ////
        cmd = 16'h0D02;
        if (&cnt) begin
          wrt = 1'b1;
          nxt_state = INIT2;
        end
      end
    endcase
  end

endmodule
