module PB_release (
  input logic PB,        // pushbutton input
  input logic rst_n,     // reset (active low, asynch)
  input logic clk,       // clock
  output logic released  // asserts when button has been released
);
  /*
      ┌─┐  ┌─┐   ┌─┐
  PB ─┤ ├q1┤ ├q2─┤ ├q3─┐   ┌───┐
      └ʌ┘  └ʌ┘ │ └ʌ┘   └──o│ & │──╴ released
               │       ┌───┤   │
               └───────┘   └───┘
  */

  // Internal signals
  logic q1, q2, q3;

  // Three flops
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      q1 <= 1'b1;
      q2 <= 1'b1;
      q3 <= 1'b1;
    end else begin
      q1 <= PB;
      q2 <= q1;
      q3 <= q2;
    end
  end

  // set released high if q3 is low and q2 is high
  assign released = (!q3 && q2) ? 1'b1 : 1'b0;
endmodule