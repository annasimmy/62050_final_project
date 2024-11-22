`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
   input wire          clk_100mhz,
   output logic [15:0] led,
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
  
  logic debounced_output;
  debouncer btn1_db(.clk_in(clk_100_passthrough),
                    .rst_in(btn[0]),
                    .dirty_in(btn[1]),
                    .clean_out(debounced_output));
  logic debounced_output2;
  debouncer btn2_db(.clk_in(clk_pixel),
                    .rst_in(btn[0]),
                    .dirty_in(btn[2]),
                    .clean_out(debounced_output2));

  logic prev_output;
  logic prev_output2;

  always_ff @(posedge clk_100_passthrough) begin
    prev_output <= debounced_output;
  end
  always_ff @(posedge clk_pixel) begin
    prev_output2 <= debounced_output2;
  end

  logic [7:0]          red,green,blue;
  logic [7:0]          red1,green1,blue1;
  logic [7:0]          red2,green2,blue2;
  
  logic           hsync1,vsync1,active_draw1;
  logic           hsync2,vsync2,active_draw2;
  logic           hsync,vsync,active_draw;

  text_display display_text
    (.clk_in(clk_100_passthrough),
     .clk_pixel(clk_pixel),
     .sys_rst_pixel(btn[0]),
     .data_valid_in(debounced_output && !prev_output),
     .data_in(sw[4:0]),
     .scroll_dir_in((debounced_output2 && !prev_output2) ? sw[6:5] : 0),
     .red_out(red1),
     .green_out(green1),
     .blue_out(blue1),
     .hsync_hdmi_out(hsync1),
     .vsync_hdmi_out(vsync1),
     .active_draw_hdmi_out(active_draw1)
    );
    
  enigma_display display_enigma
    (.clk_in(clk_100_passthrough),
     .clk_pixel(clk_pixel),
     .sys_rst_pixel(btn[0]),
     .orig_letter_in(sw[4:0]),
     .code_letter_in(sw[9:5]),
     .red_out(red2),
     .green_out(green2),
     .blue_out(blue2),
     .hsync_hdmi_out(hsync2),
     .vsync_hdmi_out(vsync2),
     .active_draw_hdmi_out(active_draw2)
    );

  always_comb begin
    if(sw[15]) begin
      red = red1;
      green = green1;
      blue = blue1;
      hsync = hsync1;
      vsync = vsync1;
      active_draw = active_draw1;
    end else begin
      red = red2;
      green = green2;
      blue = blue2;
      hsync = hsync2;
      vsync = vsync2;
      active_draw = active_draw2;
    end
  end
  

  
  logic [9:0] tmds_10b [0:2];
  logic tmds_signal [2:0];

  tmds_encoder tmds_red(
      .clk_in(clk_pixel),
      .rst_in(btn[0]),
      .data_in(red),
      .control_in(2'b0),
      .ve_in(active_draw),
      .tmds_out(tmds_10b[2]));

  tmds_encoder tmds_green(
      .clk_in(clk_pixel),
      .rst_in(btn[0]),
      .data_in(green),
      .control_in(2'b0),
      .ve_in(active_draw),
      .tmds_out(tmds_10b[1]));

  tmds_encoder tmds_blue(
      .clk_in(clk_pixel),
      .rst_in(btn[0]),
      .data_in(blue),
      .control_in({vsync,hsync}),
      .ve_in(active_draw),
      .tmds_out(tmds_10b[0]));

      

  //three tmds_serializers (blue, green, red):
  tmds_serializer red_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(btn[0]),
        .tmds_in(tmds_10b[2]),
        .tmds_out(tmds_signal[2]));
  tmds_serializer green_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(btn[0]),
        .tmds_in(tmds_10b[1]),
        .tmds_out(tmds_signal[1]));
  tmds_serializer blue_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(btn[0]),
        .tmds_in(tmds_10b[0]),
        .tmds_out(tmds_signal[0]));

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