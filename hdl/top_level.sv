`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
   input wire          clk_100mhz,
   output logic [15:0] led,
  //  // camera bus
  //  input wire [7:0]    camera_d, // 8 parallel data wires
  //  output logic        cam_xclk, // XC driving camera
  //  input wire          cam_hsync, // camera hsync wire
  //  input wire          cam_vsync, // camera vsync wire
  //  input wire          cam_pclk, // camera pixel clock
  //  inout wire          i2c_scl, // i2c inout clock
  //  inout wire          i2c_sda, // i2c inout data
   input wire [15:0]   sw,
   input wire [3:0]    btn,
   output logic [2:0]  rgb0,
   output logic [2:0]  rgb1,
   // seven segment
   output logic [3:0]  ss0_an,//anode control for upper four digits of seven-seg display
   output logic [3:0]  ss1_an,//anode control for lower four digits of seven-seg display
   output logic [6:0]  ss0_c, //cathode controls for the segments of upper four digits
   output logic [6:0]  ss1_c, //cathod controls for the segments of lower four digits
   // hdmi port
   output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
   output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
   output logic        hdmi_clk_p, hdmi_clk_n //differential hdmi clock
   );

  assign rgb0 = 0;
  assign rgb1 = 0;
  assign ss0_an = 0;
  assign ss1_an = 0;
  assign ss0_c = 0;
  assign ss1_c = 0;
  
  // Clock and Reset Signals
  logic          clk_camera;
  logic          clk_pixel;
  logic          clk_5x;
  logic          clk_xc;

  logic          clk_100_passthrough;

  // clocking wizards to generate the clock speeds we need for our different domains
  // clk_camera: 200MHz, fast enough to comfortably sample the cameera's PCLK (50MHz)
  cw_hdmi_clk_wiz wizard_hdmi
    (.sysclk(clk_100_passthrough),
    .clk_pixel(clk_pixel),
    .clk_tmds(clk_5x),
    .reset(0));

  cw_fast_clk_wiz wizard_migcam
    (.clk_in1(clk_100mhz),
    .clk_camera(clk_camera),
    .clk_xc(clk_xc),
    .clk_100(clk_100_passthrough),
    .reset(0));

  logic tmds_signal [2:0];
  
  
  logic debounced_output;
 
  debouncer btn1_db(.clk_in(clk_100_passthrough),
                    .rst_in(btn[0]),
                    .dirty_in(btn[1]),
                    .clean_out(debounced_output));

  logic prev_output;

  always_ff @(posedge clk_100_passthrough) begin
    prev_output <= debounced_output;
  end


  text_display display
    (.clk_in(clk_100_passthrough),
     .clk_pixel(clk_pixel),
     .clk_5x(clk_5x),
     .sys_rst_pixel(btn[0]),
     .data_valid_in(debounced_output && !prev_output),
     .data_in(sw[4:0]),
     .tmds_red_out(tmds_signal[2]),
     .tmds_green_out(tmds_signal[1]),
     .tmds_blue_out(tmds_signal[0])
    );

  //output buffers generating differential signals:
  //three for the r,g,b signals and one that is at the pixel clock rate
  //the HDMI receivers use recover logic coupled with the control signals asserted
  //during blanking and sync periods to synchronize their faster bit clocks off
  //of the slower pixel clock (so they can recover a clock of about 742.5 MHz from
  //the slower 74.25 MHz clock)
  OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
  OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
  OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
  OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));
  assign led[15:0] = 0;

endmodule // top_level


`default_nettype wire