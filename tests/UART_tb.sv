module UART_tb();
  logic clk, rst_n;
  logic TX;
  logic [7:0] tx_data;
  logic trmt, tx_done;
  logic [7:0] rx_data;
  logic clr_rdy, rdy;

  // DUTs
  UART_tx  txDUT(.clk    (clk),
                 .rst_n  (rst_n),
                 .trmt   (trmt),
                 .tx_data(tx_data),
                 .tx_done(tx_done),
                 .TX     (TX));

  UART_rcv rxDUT(.clk    (clk),
                 .rst_n  (rst_n),
                 .RX     (TX),
                 .clr_rdy(clr_rdy),
                 .rdy    (rdy),
                 .rx_data(rx_data));

  // clock
  initial clk = 0;
  always #5 clk = ~clk;

  logic [8:0] octet;
  initial begin
    // reset
    rst_n = 0;
    clr_rdy = 1;
    @(negedge clk) rst_n = 1; clr_rdy = 0;

    for (octet = 0; octet <= 8'hff; octet++) begin
      tx_data = octet;
      trmt = 1;
      @(negedge clk) trmt = 0;
      @(posedge tx_done); // wait for end

      if (tx_data !== rx_data) begin
        $error("tx_data != rx_data (%h != %h)", tx_data, rx_data);
      end

      if (!rdy) begin
        $error("rx not done even though tx finished");
      end

      @(negedge clk);
      clr_rdy = 1;
      @(negedge clk) clr_rdy = 0;
    end

    $display("--> tests passed!");
    $finish();
  end
endmodule
