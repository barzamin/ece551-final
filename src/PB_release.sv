module PB_release(PB, clk, rst_n, released);
  // Inputs/Outputs
  input PB, clk, rst_n;
  output released;

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