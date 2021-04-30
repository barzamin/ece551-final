/*------------------------------------------------------------------------------
--  This module performs the computations used to control the flight of the 
--  Quadcopter.
--
--  Team: MEI
--  Authors:
--    * Mitchell Kitzinger
--    * Erin Marshall
--    * Isaac Colbert
--  Term: Spring 2021
------------------------------------------------------------------------------*/
module PD_math_pipeline (
  input wire clk,            // clock
  input wire rst_n,          // reset (active low)
  input wire vld,            // new inertial sensor reading is valid
  input wire [15:0] desired, // desired output
  input wire [15:0] actual,  // actual output

  output reg signed [11:0] dterm, // 12-bit signed dterm = sat7(D_diff) * DTERM
  output reg signed [9 :0] pterm  // 10-bit signed pterm = 5/8 * err_sat
);
  localparam DTERM = 5'b00111;
  localparam D_QUEUE_DEPTH = 12;

  logic [16:0] err;
  logic [9:0] err_sat, D_diff;
  logic [6:0] D_diff_sat;
  reg [9:0] prev_err[0:D_QUEUE_DEPTH-1];
  logic [9:0] err_sat_half, err_sat_eighth;

  // type logic for pipeline reg
  logic [6:0] D_diff_sat_ff;
  logic signed [9:0] pterm_ff;
  logic [9:0] err_sat_ff;

  // genvar variable for derivative queue
  genvar i;

  assign err = {actual[15],actual} - {desired[15],desired};

  // Saturate err to 10 bits
  assign err_sat = (err[16]) ?
            ((&err[15:9] == 0) ? 10'h200 : err[9:0]) :
            ((|err[15:9]) ? 10'h1ff : err[9:0]);

  // err_sat pipeline reg
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      err_sat_ff <= 10'h000;
    else
      err_sat_ff <= err_sat;
  end

  //////////////////////////////////////////////
  // Parametizable Queue depth for Derivative //
  //////////////////////////////////////////////
  generate
    for (i = 0; i < D_QUEUE_DEPTH; i = i + 1) begin
      always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
          prev_err[i] <= 10'h000;
        else if (vld)
          if (i == 0) begin
            prev_err[0] <= err_sat;
          end else begin
            prev_err[i] <= prev_err[i-1];
          end
      end
    end
  endgenerate

  // Subtract past error from current error to approximate derivative
  assign D_diff = err_sat_ff - prev_err[D_QUEUE_DEPTH-1];

  // Saturate D_diff to 7 bits
  assign D_diff_sat = (D_diff[9]) ?
              ((&D_diff[8:6] == 0) ? 7'h40 : D_diff[6:0]) :
              ((|D_diff[8:6]) ? 7'h3f : D_diff[6:0]);

  // Pipeline register for d_term before multiplying
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      D_diff_sat_ff <= 7'h00;
    else
      D_diff_sat_ff <= D_diff_sat;
  end

  // Signed multiply of D_diff_sat
  assign dterm = $signed(D_diff_sat_ff) * $signed(DTERM);

  // Shift err_sat right once to divide by two, sign extending msb
  assign err_sat_half = {err_sat[9], err_sat[9:1]};
  // Shift err_sat right three times to divide by eight, sign extending msb
  assign err_sat_eighth = {err_sat[9], err_sat[9], err_sat[9], err_sat[9:3]};

  // Add together the eighth and half to calculate 5/8
  assign pterm_ff = err_sat_half + err_sat_eighth;

  // Pipeline register for p_term after adding
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      pterm <= 10'h000;
    else
      pterm <= pterm_ff;
  end

endmodule