module ESC_interface_tb ();
  logic clk, rst_n, wrt;
  logic [10:0] SPEED;
  logic PWM;

  ESC_interface DUT(.clk  (clk),
                    .rst_n(rst_n),
                    .wrt  (wrt),
                    .SPEED(SPEED),
                    .PWM  (PWM));

  initial clk = 0;
  always #5 assign clk = ~clk;

  initial begin
    rst_n = 0;
    @(posedge clk);
    @(negedge clk) rst_n = 1;

    SPEED = 0;
    wrt = 1;

    @(posedge clk); // one cycle to get through output flop
    @(negedge clk); wrt = 0; // deassert wrt; it should only be asserted for one cycle
    repeat (6250) begin
      @(posedge clk);
      if (PWM != 1) begin
        $display("PWM pulse ended early"); $stop();
      end
    end
    @(posedge clk); @(posedge clk);
    if (PWM != 0) begin
      $display("pulse should've ended"); $stop();
    end

    SPEED = 2047;
    wrt = 1;

    @(posedge clk); // one cycle to get through output flop
    @(negedge clk); wrt = 0; // deassert wrt; it should only be asserted for one cycle
    repeat (12391) begin
      @(posedge clk);
      if (PWM != 1) begin
        $display("PWM pulse ended early"); $stop();
      end
    end
    @(posedge clk); @(posedge clk);
    if (PWM != 0) begin
      $display("pulse should've ended"); $stop();
    end

    SPEED = 1023;
    wrt = 1;

    @(posedge clk); // one cycle to get through output flop
    @(negedge clk); wrt = 0; // deassert wrt; it should only be asserted for one cycle
    repeat (9319) begin
      @(posedge clk);
      if (PWM != 1) begin
        $display("PWM pulse ended early"); $stop();
      end
    end
    @(posedge clk); @(posedge clk);
    if (PWM != 0) begin
      $display("pulse should've ended"); $stop();
    end


    SPEED = 1365;
    wrt = 1;

    @(posedge clk); // one cycle to get through output flop
    @(negedge clk); wrt = 0; // deassert wrt; it should only be asserted for one cycle
    repeat (10345) begin
      @(posedge clk);
      if (PWM != 1) begin
        $display("PWM pulse ended early"); $stop();
      end
    end
    @(posedge clk); @(posedge clk);
    if (PWM != 0) begin
      $display("pulse should've ended"); $stop();
    end


    $display("--> testbench passed");
    $finish();
  end
endmodule
