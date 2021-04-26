module PD_math (
  input wire logic clk,   // clock
  input wire logic rst_n, // reset (active low)
  input wire logic vld, // new inertial sensor reading is valid
  input wire logic [15:0] desired, // desired output
  input wire logic [15:0] actual, // actual output

  output wire logic signed [11:0] dterm, // 12-bit signed dterm = sat7(D_diff) * DTERM
  output wire logic signed [9 :0] pterm  // 10-bit signed pterm = 5/8 * err_sat
);

  localparam DTERM = 5'b00111;
  localparam D_QUEUE_DEPTH = 12; // length of derivative delay queue

  logic [16:0] err;
  logic [9:0] err_sat, D_diff;
  logic [6:0] D_diff_sat;
  reg [9:0] prev_err[0:D_QUEUE_DEPTH-1];
  logic [9:0] err_sat_half, err_sat_eighth;
  genvar i;

  assign err = {actual[15],actual} - {desired[15],desired};

  // Saturate err to 10 bits
  assign err_sat = (err[16]) ?
            ((&err[15:9] == 0) ? 10'h200 : err[9:0]) :
            ((|err[15:9]) ? 10'h1ff : err[9:0]);

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
  assign D_diff = err_sat - prev_err[D_QUEUE_DEPTH-1];

  // Saturate D_diff to 7 bits
  assign D_diff_sat = (D_diff[9]) ?
              ((&D_diff[8:6] == 0) ? 7'h40 : D_diff[6:0]) :
              ((|D_diff[8:6]) ? 7'h3f : D_diff[6:0]);

  // Signed multiply of D_diff_sat
  assign dterm = $signed(D_diff_sat) * $signed(DTERM);

  // Shift err_sat right once to divide by two, sign extending msb
  assign err_sat_half = {err_sat[9], err_sat[9:1]};
  // Shift err_sat right three times to divide by eight, sign extending msb
  assign err_sat_eighth = {err_sat[9], err_sat[9], err_sat[9], err_sat[9:3]};

  // Add together the eighth and half to calculate 5/8
  assign pterm = err_sat_half + err_sat_eighth;

endmodule