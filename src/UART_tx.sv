module UART_tx(
  input logic clk,
  input logic rst_n,
  input logic trmt,
  input logic [7:0] tx_data,
  output reg tx_done,
  output logic TX
);

  // Intermediate declarations
  logic [8:0] tx_shft_reg;
  logic [11:0] baud_cnt;
  logic [3:0] bit_cnt;
  logic init, transmitting, shift, set_done;

  // State declarations
  typedef enum reg {IDLE, TRANS} state_t;
  state_t state, nxt_state;

  // State machine
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= nxt_state;
  end

  // State machine nxt_state logic
  always_comb begin
    //// Default outputs ////
    init = 0;
    transmitting = 0;
    set_done = 0;
    case(state)
      TRANS: if (bit_cnt == 10) begin
        set_done = 1'b1;
        nxt_state = IDLE;
      end else begin
        transmitting = 1'b1;
        nxt_state = TRANS;
      end
      //// Default Case: IDLE ////
      default: if (trmt) begin
        init = 1'b1;
        nxt_state = TRANS;
      end else begin
        nxt_state = IDLE;
      end
    endcase
  end

  // Shift register
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      tx_shft_reg <= 9'h1FF;
    else if (init)
      // Data with start bit appended as lsb
      tx_shft_reg <= {tx_data, 1'b0};
    else if (shift)
      tx_shft_reg <= {1'b1,tx_shft_reg[8:1]};
  end
  assign TX = tx_shft_reg[0];

  // Baud counter
  always_ff @(posedge clk) begin
    if (init || shift)
      baud_cnt <= 12'h000;
    else if (transmitting)
      baud_cnt <= baud_cnt + 1;
  end
  // Is the baude period over?
  assign shift = (baud_cnt == 12'hA2C) ? 1'b1 : 1'b0;

  // Bit counter
  always_ff @(posedge clk) begin
    if (init)
      bit_cnt <= 4'h0;
    else if (shift)
      bit_cnt <= bit_cnt + 1;
  end

  // output logic
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      tx_done <= 1'b0;
    else if (set_done)
      tx_done <= 1'b1;
    else if (init)
      tx_done <= 1'b0;
  end


endmodule