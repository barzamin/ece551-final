`default_nettype none
/*------------------------------------------------------------------------------
--  Packs a command byte and two bytes of data and sends it via serial; also
--  recieves response bytes over serial.
--
--  Team: MEI
--  Authors:
--    * Mitchell Kitzinger
--    * Erin Marshall
--    * Isaac Colbert
--  Term: Spring 2021
------------------------------------------------------------------------------*/
module RemoteComm(
  input wire logic clk, rst_n,   // clock and active low reset
  input wire logic RX,           // serial data input
  input wire logic send_cmd,     // indicates to tranmit 24-bit command (cmd)
  input wire logic [7:0] cmd,    // 8-bit command to send
  input wire logic [15:0] data,  // 16-bit data that accompanies command
  input wire logic clr_resp_rdy, // asserted in test bench to knock down resp_rdy

  output wire logic TX,        // serial data output
  output reg        cmd_sent,  // indicates transmission of command complete
  output wire logic resp_rdy,  // indicates 8-bit response has been received
  output wire logic [7:0] resp // 8-bit response from DUT
);

  // internal signals
  logic [7:0] internal_high_data, internal_low_data, tx_data;
  logic [1:0] select;
  logic tx_done;
  logic done, trmt;
  typedef enum {IDLE, SEND_HIGH, SEND_LOW, WAITING} state_t;
  state_t state, next_state;

  // uart transciever
  UART iUART(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .tx_data(tx_data), .trmt(trmt), .tx_done(tx_done), .rx_data(resp), .rx_rdy(resp_rdy), .clr_rx_rdy(clr_resp_rdy));

  // MUX to select which byte to send
  always_comb begin
    case(select)
      2'b00: tx_data = cmd;
      2'b01: tx_data = internal_high_data;
      2'b10: tx_data = internal_low_data;
      default tx_data = 8'b0;
    endcase
  end

  // Store the data bytes
  always@(posedge clk) begin
    if(send_cmd) begin //  Need to store data since it may not be held
      internal_high_data <= data[15:8];
      internal_low_data <= data[7:0];
    end
  end

  // cmd_sent logic
  always@(posedge clk, negedge rst_n) begin
    if(!rst_n) cmd_sent <= 1'b0;
    else if(done) cmd_sent <= 1'b1;
    else if(send_cmd) cmd_sent <= 1'b0;
  end

  // State flops
  always@(posedge clk, negedge rst_n) begin
    if(!rst_n) state <= IDLE;
    else state <= next_state;
  end

  // State transition logic
  always_comb begin
    select = 2'b00;
    trmt = 1'b0;
    done = 1'b0;

    // next_state defaulting to prevent a latch was implemented after seeing weirdly
    // low FSM transition coverage in the QuestaSim coverage reports.
    next_state = IDLE;
    case(state)
      IDLE: begin
        if(send_cmd) begin
          select = 2'b00;
          trmt = 1'b1;
          next_state = SEND_HIGH;
        end
      end
      SEND_HIGH: begin
        next_state = SEND_HIGH;
        if(tx_done) begin // Cmd field was sent
          select = 2'b01;
          trmt = 1'b1;
          next_state = SEND_LOW;
        end
      end
      SEND_LOW: begin
        next_state = SEND_LOW;
        if(tx_done) begin // High data was sent
          select = 2'b10;
          trmt = 1'b1;
          next_state = WAITING;
        end
      end
      WAITING: begin
        next_state = WAITING;
        if(tx_done) begin // Low data was sent, we're done.
          next_state = IDLE;
          done = 1'b1;
        end
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end
endmodule
