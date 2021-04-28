module flght_cntrl_chk_nq_tb();

  // DUT signals
  logic clk, rst_n, vld, inertial_cal;
  logic [15:0] d_ptch, d_roll, d_yaw;
  logic [15:0] ptch, roll, yaw;
  logic [8:0] thrst;
  logic [10:0] frnt_spd, bck_spd, lft_spd, rght_spd;

  // Mem declarations
  reg [107:0] mem_stim[0:1999];		// 108 bits wide, 2000 entries
  reg [43:0] mem_resp[0:1999];		// 44 bits wide, 2000 entries

  // TB signals
  logic [10:0] i;
  logic [107:0] curr_stim;
  logic [43:0] curr_resp;

  // file handlers
  integer stim_file, resp_file;

  // DUT instantiation
  // NOTE we don't use pipelined version since that won't pass timing-exact tests
  //      due to end-to-end pipeline delay; this is more for math validation.
  flght_cntrl iDUT(.clk(clk), .rst_n(rst_n), .vld(vld), .inertial_cal(inertial_cal),
            .d_ptch(d_ptch), .d_roll(d_roll), .d_yaw(d_yaw), .ptch(ptch),
            .roll(roll), .yaw(yaw), .thrst(thrst), .frnt_spd(frnt_spd),
            .bck_spd(bck_spd), .lft_spd(lft_spd), .rght_spd(rght_spd));

  initial begin
    // Read in contents of files
    $readmemh("flght_cntrl_stim_nq.hex",mem_stim);
    $readmemh("flght_cntrl_resp_nq.hex",mem_resp);

    clk = 0;

    // For loop for checking values
    for(i = 0; i < 2000; i = i + 1) begin
      curr_stim = mem_stim[i];
      curr_resp = mem_resp[i];
      // Assign stimulus to respective signals
      rst_n = curr_stim[107];
      vld = curr_stim[106];
      inertial_cal = curr_stim[105];
      d_ptch = curr_stim[104:89];
      d_roll = curr_stim[88:73];
      d_yaw = curr_stim[72:57];
      ptch = curr_stim[56:41];
      roll = curr_stim[40:25];
      yaw = curr_stim[24:9];
      thrst = curr_stim[8:0];

      repeat (1) @(posedge clk) #1;					// Wait for positive clk edge and then wait #1 time unit

      if (frnt_spd !== curr_resp[43:33]) begin
        $error("ERR: frnt_spd did not match expected resp value on iteration %d\nExpected: 10'h%h, Returned: 10'h%h",i,curr_resp[43:33], frnt_spd);
      end
      if (bck_spd !== curr_resp[32:22]) begin
        $error("ERR: bck_spd did not match expected resp value on iteration %d\nExpected: 10'h%h, Returned: 10'h%h",i,curr_resp[32:22], bck_spd);
      end
      if (lft_spd !== curr_resp[21:11]) begin
        $error("ERR: lft_spd did not match expected resp value on iteration %d\nExpected: 10'h%h, Returned: 10'h%h",i,curr_resp[21:11], lft_spd);
      end
      if (rght_spd !== curr_resp[10:0]) begin
        $error("ERR: rght_spd did not match expected resp value on iteration %d\nExpected: 10'h%h, Returned: 10'h%h",i,curr_resp[10:0], rght_spd);
      end
    end

    $display("Test passed with new queue!");
    $finish();
  end

  always
    #5 clk = ~clk;

endmodule