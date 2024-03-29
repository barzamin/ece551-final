/*------------------------------------------------------------------------------
--  This module produces a PWM pulse that is used to control the motors of 
--  the Quadcopter.
--
--  Team: MEI
--  Authors:
--    * Mitchell Kitzinger
--    * Erin Marshall
--    * Isaac Colbert
--  Term: Spring 2021
------------------------------------------------------------------------------*/
module ESC_interface_pipeline (
  input wire clk,          // clock
  input wire rst_n,        // asynchronous reset active low
  input wire wrt,          // init a pulse
  input wire [10:0] SPEED, // speed input
  output reg PWM           // esc control output
);

  // Intermediate wire declarations
  wire [12:0] mult_rslt;
  wire [13:0] num_ticks;
  wire Rst, Set;
  reg [13:0] q1;

  // logic for pipeline reg
  logic [10:0] SPEED_ff;
  logic wrt_ff;

  // Pipeline reg
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      SPEED_ff <= 11'h000;
    else
      SPEED_ff <= SPEED;
  end

  // Pipeline for wrt sig
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      wrt_ff <= 1'b0;
    else
      wrt_ff <= wrt;
  end

  // multiply speed input by three and add to 6250 to get number of clk cycles
  assign mult_rslt = SPEED_ff * 2'b11;
  assign num_ticks = mult_rslt + 13'h186a;

  // First flop that counts down until num_ticks is 0
  always @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      q1 <= 14'h0000;
    else if (wrt_ff)
      q1 <= num_ticks;
    else
      q1 <= q1 - 1'b1;
  end

  // Set Rst high when q1 is all zeros
  assign Rst = (~|(q1)) ? 1'b1 : 1'b0;

  // Set goes high when wrt is high
  assign Set = (wrt_ff) ? 1'b1 : 1'b0;

  // Final flop with asynch reset, PWM goes to 1 when set is high,
  // 0 when Rst is high, and retains its value if neither are high.
  always @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      PWM <= 1'b0;
    else if (Rst)
      PWM <= 1'b0;
    else if (Set)
      PWM <= 1'b1;
  end

endmodule
