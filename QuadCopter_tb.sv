`default_nettype none
module QuadCopter_tb();

//// Interconnects to DUT/support defined as type wire /////
wire SS_n, SCLK, MOSI, MISO, INT;
wire RX,TX;
wire [7:0] resp;                // response from DUT
wire cmd_sent, resp_rdy;
wire frnt_ESC, back_ESC, left_ESC, rght_ESC;

////// Stimulus is declared as type reg ///////
reg clk, RST_n;
reg [7:0] host_cmd;             // command host is sending to DUT
reg [15:0] data;                // data associated with command
reg send_cmd;                   // asserted to initiate sending of command
reg clr_resp_rdy;               // asserted to knock down resp_rdy

wire [7:0] LED;

//// localparams for command encoding ///
localparam SET_PITCH 	= 8'h02;
localparam SET_ROLL 	= 8'h03;
localparam SET_YAW		= 8'h04;
localparam SET_THRST	= 8'h05;
localparam CALIBRATE	= 8'h06;
localparam E_LAND		= 8'h07;
localparam MOTORS_OFF	= 8'h08;

////////////////////////////////////////////////////////////////
// Instantiate Physical Model of Copter with Inertial sensor //
//////////////////////////////////////////////////////////////  
CycloneIV iQuad(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
                .MOSI(MOSI),.INT(INT),.frnt_ESC(frnt_ESC),.back_ESC(back_ESC),
                .left_ESC(left_ESC),.rght_ESC(rght_ESC));


////// Instantiate DUT ////////
QuadCopter iDUT(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MOSI(MOSI),.MISO(MISO),
                .INT(INT),.RX(RX),.TX(TX),.FRNT(frnt_ESC),.BCK(back_ESC),
                .LFT(left_ESC),.RGHT(rght_ESC));


//// Instantiate Master UART (mimics host commands) //////
RemoteComm iREMOTE(.clk(clk), .rst_n(RST_n), .RX(TX), .TX(RX),
                     .cmd(host_cmd), .data(data), .send_cmd(send_cmd),
                     .cmd_sent(cmd_sent), .resp_rdy(resp_rdy),
                     .resp(resp), .clr_resp_rdy(clr_resp_rdy));


initial begin
	clk = 1'b0;
	RST_n = 1'b0;
	repeat(5) @(negedge clk);
	RST_n = 1'b1;
end

always
  #10 clk = ~clk;

/// perhaps include a tb_tasks file with helper tasks for testing.

endmodule
