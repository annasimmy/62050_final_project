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
  logic          sys_rst_pixel;

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


  assign sys_rst_pixel = btn[0]; //use for resetting hdmi/draw side of logic

  logic [4:0] text [511:0];
  always_comb begin
    for (int i = 0; i < 26; i = i+1) begin
      text[i] = i;
    end
  end

  // video signal generator signals
  logic          hsync_hdmi;
  logic          vsync_hdmi;
  logic [10:0]   hcount_hdmi;
  logic [9:0]    vcount_hdmi;
  logic          active_draw_hdmi;
  logic [5:0]    frame_count_hdmi;
  logic          nf_hdmi;



  // rgb output values
  logic [7:0]          red,green,blue;

  logic [10:0] hcount_pipe [4:0];
  logic [9:0] vcount_pipe [4:0];
  logic [10:0] hcount_left_pipe [4:0];
  logic [9:0] vcount_up_pipe [4:0];
  logic [10:0] hcount_pipe_2 [4:0];
  logic [9:0] vcount_pipe_2 [4:0];
  logic          hsync_hdmi_pipe [8:0];
  logic          vsync_hdmi_pipe [8:0];
  logic          active_draw_hdmi_pipe [8:0];

  always_ff @(posedge clk_pixel)begin
    hcount_pipe[0] <= hcount_hdmi;
    vcount_pipe[0] <= vcount_hdmi;
    hsync_hdmi_pipe[0] <= hsync_hdmi;
    vsync_hdmi_pipe[0] <= vsync_hdmi;
    active_draw_hdmi_pipe[0] <= active_draw_hdmi;
    if(hcount_hdmi >= 640) begin
      hcount_left_pipe[0] <= 16;
      hcount_pipe_2[0] <= hcount_hdmi - 640;
    end else begin
      hcount_left_pipe[0] <= 0;
      hcount_pipe_2[0] <= hcount_hdmi;
    end
    if(vcount_hdmi >= 360) begin
      vcount_up_pipe[0] <= 8;
      vcount_pipe_2[0] <= vcount_hdmi - 360;
    end else begin
      vcount_up_pipe[0] <= 0;
      vcount_pipe_2[0] <= vcount_hdmi;
    end
    for (int i = 1; i <= 8; i = i+1)begin
      hsync_hdmi_pipe[i] <= hsync_hdmi_pipe[i - 1];
      vsync_hdmi_pipe[i] <= vsync_hdmi_pipe[i - 1];
      active_draw_hdmi_pipe[i] <= active_draw_hdmi_pipe[i - 1];
    end
    for (int i = 1; i <= 4; i = i+1)begin
      hcount_pipe[i] <= hcount_pipe[i - 1];
      vcount_pipe[i] <= vcount_pipe[i - 1];
      if(hcount_pipe_2[i - 1] >= (640 >> i)) begin
        hcount_left_pipe[i] <= hcount_left_pipe[i - 1] + (16 >> i);
        hcount_pipe_2[i] <= hcount_pipe_2[i - 1] - (640 >> i);
      end else begin
        hcount_left_pipe[i] <= hcount_left_pipe[i - 1];
        hcount_pipe_2[i] <= hcount_pipe_2[i - 1];
      end
    end
    for (int i = 1; i <= 3; i = i+1)begin
      if(vcount_pipe_2[i - 1] >= (360 >> i)) begin
        vcount_up_pipe[i] <= vcount_up_pipe[i - 1] + (8 >> i);
        vcount_pipe_2[i] <= vcount_pipe_2[i - 1] - (360 >> i);
      end else begin
        vcount_up_pipe[i] <= vcount_up_pipe[i - 1];
        vcount_pipe_2[i] <= vcount_pipe_2[i - 1];
      end
    end
    vcount_pipe[4] <= vcount_pipe[3];
    vcount_up_pipe[4] <= vcount_up_pipe[3];
  end

  // width 228, height 225 for 6x5 grid
  // width 38, height 45 per letter
  // if I do 40x45, that perfectly fits 32x16 letters in a 1280x720 display
  image_sprite #(
    .WIDTH(228),
    .HEIGHT(225))
    letter_sprite (
    .pixel_clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .hcount_in(hcount_pipe[4]),  
    .vcount_in(vcount_pipe[4]),  
    .x_in(hcount_left_pipe[4] * 40),
    .y_in(vcount_up_pipe[4] * 45),
    .letter(text[hcount_left_pipe[4] + vcount_up_pipe[4] * 32]),
    .red_out(red),
    .green_out(green),
    .blue_out(blue));



  // HDMI video signal generator
  video_sig_gen vsg
    (
    .pixel_clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .hcount_out(hcount_hdmi),
    .vcount_out(vcount_hdmi),
    .vs_out(vsync_hdmi),
    .hs_out(hsync_hdmi),
    .nf_out(nf_hdmi),
    .ad_out(active_draw_hdmi),
    .fc_out(frame_count_hdmi)
    );


   logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
   logic       tmds_signal [2:0]; //output of each TMDS serializer!

   //three tmds_encoders (blue, green, red)
   //note green should have no control signal like red
   //the blue channel DOES carry the two sync signals:
   //  * control_in[0] = horizontal sync signal
   //  * control_in[1] = vertical sync signal

   tmds_encoder tmds_red(
       .clk_in(clk_pixel),
       .rst_in(sys_rst_pixel),
       .data_in(red),
       .control_in(2'b0),
       .ve_in(active_draw_hdmi_pipe[8]),
       .tmds_out(tmds_10b[2]));

   tmds_encoder tmds_green(
         .clk_in(clk_pixel),
         .rst_in(sys_rst_pixel),
         .data_in(green),
         .control_in(2'b0),
         .ve_in(active_draw_hdmi_pipe[8]),
         .tmds_out(tmds_10b[1]));

   tmds_encoder tmds_blue(
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .data_in(blue),
        .control_in({vsync_hdmi_pipe[8],hsync_hdmi_pipe[8]}),
        .ve_in(active_draw_hdmi_pipe[8]),
        .tmds_out(tmds_10b[0]));


   //three tmds_serializers (blue, green, red):
   tmds_serializer red_ser(
         .clk_pixel_in(clk_pixel),
         .clk_5x_in(clk_5x),
         .rst_in(sys_rst_pixel),
         .tmds_in(tmds_10b[2]),
         .tmds_out(tmds_signal[2]));
   tmds_serializer green_ser(
         .clk_pixel_in(clk_pixel),
         .clk_5x_in(clk_5x),
         .rst_in(sys_rst_pixel),
         .tmds_in(tmds_10b[1]),
         .tmds_out(tmds_signal[1]));
   tmds_serializer blue_ser(
         .clk_pixel_in(clk_pixel),
         .clk_5x_in(clk_5x),
         .rst_in(sys_rst_pixel),
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


// `timescale 1ns / 1ps
// `default_nettype none

// module top_level
//   (
//    input wire          clk_100mhz,
//    input wire [10:0] hcount_hdmi,
//    input wire [9:0] vcount_hdmi,
   
//    output logic [10:0] hcount_out,
//    output logic [9:0] vcount_out
//    );

//   // video signal generator signals

//   // rgb output values
//   logic [7:0]          red,green,blue;

//   logic [10:0] hcount_pipe [5:0];
//   logic [9:0] vcount_pipe [5:0];
//   logic [10:0] hcount_left_pipe [5:0];
//   logic [9:0] vcount_up_pipe [5:0];
//   logic [10:0] hcount_pipe_2 [5:0];
//   logic [9:0] vcount_pipe_2 [5:0];
//   always_ff @(posedge clk_100mhz)begin
//     hcount_pipe[0] <= hcount_hdmi;
//     vcount_pipe[0] <= vcount_hdmi;
//     if(hcount_hdmi >= 640) begin
//       hcount_left_pipe[0] <= 640;
//       hcount_pipe_2[0] <= hcount_hdmi - 640;
//     end else begin
//       hcount_left_pipe[0] <= 0;
//       hcount_pipe_2[0] <= hcount_hdmi;
//     end
//     if(vcount_hdmi >= 360) begin
//       vcount_up_pipe[0] <= 360;
//       vcount_pipe_2[0] <= vcount_hdmi - 360;
//     end else begin
//       vcount_up_pipe[0] <= 0;
//       vcount_pipe_2[0] <= vcount_hdmi;
//     end
//     for (int i = 1; i <= 4; i = i+1)begin
//       hcount_pipe[i] <= hcount_pipe[i - 1];
//       vcount_pipe[i] <= vcount_pipe[i - 1];
//       if(hcount_pipe_2[i - 1] >= (640 >> i)) begin
//         hcount_left_pipe[i] <= hcount_left_pipe[i - 1] + (640 >> i);
//         hcount_pipe_2[i] <= hcount_pipe_2[i - 1] - (640 >> i);
//       end else begin
//         hcount_left_pipe[i] <= hcount_left_pipe[i - 1];
//         hcount_pipe_2[i] <= hcount_pipe_2[i - 1];
//       end
//     end
//     for (int i = 1; i <= 3; i = i+1)begin
//       if(vcount_pipe_2[i - 1] >= (360 >> i)) begin
//         vcount_up_pipe[i] <= vcount_up_pipe[i - 1] + (360 >> i);
//         vcount_pipe_2[i] <= vcount_pipe_2[i - 1] - (360 >> i);
//       end else begin
//         vcount_up_pipe[i] <= vcount_up_pipe[i - 1];
//         vcount_pipe_2[i] <= vcount_pipe_2[i - 1];
//       end
//     end
//     vcount_pipe[4] <= vcount_pipe[3];
//     vcount_up_pipe[4] <= vcount_up_pipe[3];
//     hcount_out <= hcount_left_pipe[4];
//     vcount_out <= vcount_up_pipe[4];
//   end
  

// endmodule // top_level


// `default_nettype wire
