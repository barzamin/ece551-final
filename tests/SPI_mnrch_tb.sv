`default_nettype none
module SPI_mnrch_tb;
  logic clk, rst_n;

  // -- clockgen
  initial clk = 0;
  always #5 clk = ~clk;

  // -- SPI bus
  logic SS_n, SCLK, MOSI, MISO;

  // -- NEMO extra pins
  logic INT;

  // -- SPI monarch interface
  logic wrt;
  logic [15:0] wt_data;
  logic done;
  logic [15:0] rd_data;

  // -- DUT and NEMO
  SPI_mnrch spi_dut(.clk(clk),
                    .rst_n(rst_n),
                    .SS_n(SS_n),
                    .SCLK(SCLK),
                    .MOSI(MOSI),
                    .MISO(MISO),
                    .wrt(wrt),
                    .wt_data(wt_data),
                    .done(done),
                    .rd_data(rd_data));

  SPI_iNEMO1 iNEMO(.SS_n(SS_n),
                   .SCLK(SCLK),
                   .MOSI(MOSI),
                   .MISO(MISO),
                   .INT (INT));

  task spi_reg_read(input logic [7:0] register);
    wt_data = {1'b1, register[6:0], /* dummy */ 8'haa};
    wrt = 1;
    @(negedge clk) wrt = 0;
  endtask

  task spi_reg_write(input logic [7:0] register, input logic [7:0] data);
    wt_data = {1'b0, register[6:0], data};
    wrt = 1;
    @(negedge clk) wrt = 0;
  endtask

  task assert_imu_data(input logic [7:0] golden);
    assert (rd_data[7:0] === golden)
    else $fatal(1, "[!] expected resp %h !== %h", golden, rd_data[7:0]);
  endtask

  reg [95:0] imu_data[0:63];
  initial $readmemh("inert_data.hex", imu_data);
  reg [15:0] read_pitch;
  reg [15:0] read_roll;
  reg [15:0] read_yaw;
  reg [15:0] read_ax;
  reg [15:0] read_ay;
  reg [15:0] read_az;

  initial begin
    rst_n = 0;
    wrt = 0;
    wt_data = '0;
    read_pitch = '0;
    read_roll = '0;
    read_yaw = '0;
    read_ax = '0;
    read_ay = '0;
    read_az = '0;



    @(negedge clk);
    rst_n = 0;
    @(negedge clk) rst_n = 1;


    // -- check WHO_AM_I (read)
    spi_reg_read(8'h0F);
    @(posedge done) assert_imu_data(8'h6a);

    // -- configure INT assert
    @(negedge clk);
    spi_reg_write(8'h0d, 8'h02);
    @(posedge done);

    // check that NEMO got set up
    @(negedge clk);
    assert (iNEMO.NEMO_setup)
    else $fatal(1, "[!] expected NEMO_setup to go high after config");

    // -- run through data
    for (integer i = 0; i < 64; i++) begin
      @(posedge INT);

      // -- pitch
      @(negedge clk)
        spi_reg_read(8'h22); // pitchL
      @(posedge done); @(negedge clk)
        read_pitch[7:0] = rd_data[7:0];
      @(negedge clk)
        spi_reg_read(8'h23); // pitchH
      @(posedge done); @(negedge clk)
        read_pitch[15:8] = rd_data[7:0];
      assert (read_pitch === imu_data[i][47:32])
      else $fatal(1, "[!] %d pitch: %h !== %h", i, imu_data[i][47:32], read_pitch);

      // -- roll
      @(negedge clk)
        spi_reg_read(8'h24); // rollL
      @(posedge done); @(negedge clk)
        read_roll[7:0] = rd_data[7:0];
      @(negedge clk)
        spi_reg_read(8'h25); // rollH
      @(posedge done); @(negedge clk)
        read_roll[15:8] = rd_data[7:0];
      assert (read_roll === imu_data[i][31:16])
      else $fatal(1, "[!] roll:  %h !== %h", imu_data[i][31:16], read_roll);

      // -- yaw
      @(negedge clk)
        spi_reg_read(8'h26); // yawL
      @(posedge done); @(negedge clk); @(negedge clk)
        read_yaw[7:0] = rd_data[7:0];
      @(negedge clk)
        spi_reg_read(8'h27); // yawH
      @(posedge done); @(negedge clk)
        read_yaw[15:8] = rd_data[7:0];
      assert (read_yaw === imu_data[i][15:0])
      else $fatal(1, "[!] yaw:   %h !== %h", imu_data[i][15:0], read_yaw);


      // -- AX
      @(negedge clk)
        spi_reg_read(8'h28); // AXL
      @(posedge done); @(negedge clk)
        read_ax[7:0] = rd_data[7:0];
      @(negedge clk)
        spi_reg_read(8'h29); // AXH
      @(posedge done); @(negedge clk)
        read_ax[15:8] = rd_data[7:0];
      assert (read_ax === imu_data[i][95:80])
      else $fatal(1, "[!] AX: %h !== %h", imu_data[i][95:80], read_pitch);

      // -- AY
      @(negedge clk)
        spi_reg_read(8'h2a); // AYL
      @(posedge done); @(negedge clk)
        read_ay[7:0] = rd_data[7:0];
      @(negedge clk)
        spi_reg_read(8'h2b); // AYH
      @(posedge done); @(negedge clk)
        read_ay[15:8] = rd_data[7:0];
      assert (read_ay === imu_data[i][79:64])
      else $fatal(1, "[!] AY:  %h !== %h", imu_data[i][79:64], read_roll);

      // -- AZ
      @(negedge clk)
        spi_reg_read(8'h2c); // AZL
      @(posedge done); @(negedge clk)
        read_az[7:0] = rd_data[7:0];
      @(negedge clk)
        spi_reg_read(8'h2d); // AZH
      @(posedge done); @(negedge clk)
        read_az[15:8] = rd_data[7:0];
      assert (read_az === imu_data[i][63:48])
      else $fatal(1, "[!] AZ:   %h !== %h", imu_data[i][63:48], read_yaw);
    end
    $display("[*] tests passed");
    $finish();
  end
endmodule
