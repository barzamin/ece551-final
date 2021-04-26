module ESC_interface (
  input clk,          // clock
  input rst_n,        // asynchronous reset active low
  input wrt,          // starts an ESC pulse
  input [10:0] SPEED, // speed input
  output reg PWM      // ESC control output
);

  // intermediate wire declarations
  logic [13:0] setting;
  logic [13:0] counter;
  logic pulse_over;

  // computes pulse length in cycles
  assign setting = SPEED * 2'b11 + 6250;
  // decrementing counter register to track pulse length;
  // loaded with `setting` when `wrt` is asserted
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      counter <= 0;
    else if (wrt)
      counter <= setting;
    else
      counter <= counter - 1;
  end

  // asserts when counter reaches zero
  assign pulse_over = ~|counter;

  // PWM output flop; goes high on `wrt` and low on `pulse_over`
  always_ff @(posedge clk, negedge rst_n) begin
    if (wrt)
      PWM <= 1;
    else if (pulse_over || !rst_n)
      PWM <= 0;
  end
endmodule