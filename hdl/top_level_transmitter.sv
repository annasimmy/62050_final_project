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
   input wire [3:0] pmodb_i,
   output logic [3:0] pmodb_o, //output I/O used for IR input
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
  // assign ss0_an = 0;
  // assign ss1_an = 0;
  // assign ss0_c = 0;
  // assign ss1_c = 0;
  
  // Clock and Reset Signals
  logic          clk_camera;
  logic          clk_pixel;
  logic          clk_5x;
  logic          clk_xc;

  logic          clk_100_passthrough;

  logic sys_rst;
  assign sys_rst = btn[0];

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
  debouncer btn1_db(.clk_in(clk_pixel),
                    .rst_in(btn[0]),
                    .dirty_in(btn[1]),
                    .clean_out(debounced_output));
  logic debounced_output2;
  debouncer btn2_db(.clk_in(clk_pixel),
                    .rst_in(btn[0]),
                    .dirty_in(btn[2]),
                    .clean_out(debounced_output2));
  logic debounced_output3;
  debouncer btn3_db(.clk_in(clk_pixel),
                    .rst_in(btn[0]),
                    .dirty_in(btn[3]),
                    .clean_out(debounced_output3));

  logic prev_output;
  logic prev_output2;
  logic prev_output3;
  // logic display_choice;

  always_ff @(posedge clk_pixel) begin
    prev_output <= debounced_output;
    prev_output2 <= debounced_output2;
    prev_output3 <= debounced_output3;
    // if(!prev_output3 && debounced_output3) begin
    //   display_choice <= !display_choice;
    // end
  end
  // always_ff @(posedge clk_pixel) begin
  //   prev_output2 <= debounced_output2;
  // end

  logic [7:0]          red,green,blue;
  logic [7:0]          red1,green1,blue1;
  logic [7:0]          red2,green2,blue2;
  
  logic           hsync1,vsync1,active_draw1;
  logic           hsync2,vsync2,active_draw2;
  logic           hsync,vsync,active_draw;

  // text_display display_text
  //   (.clk_in(clk_100_passthrough),
  //    .clk_pixel(clk_pixel),
  //    .sys_rst_pixel(btn[0]),
  //    .data_valid_in(enigma_data_valid_decoded),
  //    .data_in(enigma_data_out_decoded),
  //    .scroll_dir_in((debounced_output2 && !prev_output2) ? sw[6:5] : 0),
  //    .red_out(red1),
  //    .green_out(green1),
  //    .blue_out(blue1),
  //    .hsync_hdmi_out(hsync1),
  //    .vsync_hdmi_out(vsync1),
  //    .active_draw_hdmi_out(active_draw1)
  //   );
    
  enigma_display display_enigma
    (.clk_in(clk_100_passthrough),
     .clk_pixel(clk_pixel),
     .sys_rst_pixel(btn[0]),
     .orig_letter_in(sw[4:0]),
     .code_letter_in(display_letter_out),
     .red_out(red2),
     .green_out(green2),
     .blue_out(blue2),
     .hsync_hdmi_out(hsync2),
     .vsync_hdmi_out(vsync2),
     .active_draw_hdmi_out(active_draw2)
    );

  always_comb begin
    red = red2; // display_choice ? red2 : red1;
    green = green2; // display_choice ? green2 : green1;
    blue = blue2; // display_choice ? blue2 : blue1;
    hsync = hsync2; //display_choice ? hsync2 : hsync1;
    vsync = vsync2; // display_choice ? vsync2 : vsync1;
    active_draw = active_draw2; //display_choice ? active_draw2 : active_draw1;
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


// Initializing rotors and original letters
  logic [8:0] rotor_select_out;
  logic [14:0] rotor_initial_out;
  logic [4:0] char_out;
  logic letter_valid_out;
  logic rotor_valid_out;

  data_module my_data (
    .clk_in(clk_100_passthrough),
    .rst_in(btn[0]),
    .letter_valid_in(btn[1]),
    .rotor_valid_in(btn[3]),
    .sw(sw),
    .rotor_valid_out(rotor_valid_out),
    .letter_valid_out(letter_valid_out),
    .rotor_select_out(rotor_select_out),
    .rotor_initial_out(rotor_initial_out),
    .char_out(char_out));


  // Enigma Initialization
  logic enigma_data_valid;
  logic last_enigma_data_valid;
  logic [4:0] enigma_data_out;
  logic enigma_ready;

  enigma enigma_encoder(.clk_in(clk_100_passthrough),
              .rst_in(btn[0]), 
              .rotor_select(rotor_select_out),
              .rotor_initial(rotor_initial_out),
              .data_valid_in(letter_valid_out),
              .rotor_valid_in(rotor_valid_out),
              .data_in(char_out),
              .ready(enigma_ready),
              .data_valid_out(enigma_data_valid),
              .data_out(enigma_data_out)
              );


  // IR Transmission from Enigma coded letters
  logic ir_busy_out;
  logic last_ir_busy_out;
  logic ir_t_signal_out;
  assign pmodb_o[2] = ir_t_signal_out;

  ir_transmitter #(.MESSAGE_LENGTH(5))
            ir_t (.clk_in(clk_100_passthrough),
                  .rst_in(sys_rst),
                  .data_valid_in(letter_buffer_valid_pipe[1]), // .data_valid_in(btn[1]),
                  .data_in(letter_buffer_out), //.data_in(sw[4:0]),
                  .busy_out(ir_busy_out),
                  .signal_out(ir_t_signal_out)); //pmodb6


  // BRAM from engima encoding to IR transmitting
  logic [10:0] enigma_letter_count; //count up to 1024 letters
  logic [10:0] ir_letter_count; //count up to 1024 letters
  logic [4:0] letter_buffer_out;
  logic letter_buffer_valid;
  logic [1:0] letter_buffer_valid_pipe;

  xilinx_true_dual_port_read_first_1_clock_ram #(
      .RAM_WIDTH(5),
      .RAM_DEPTH(1024),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE")) letter_buffer_ram (
      .clka(clk_100_passthrough),     // Clock 
      //writing port:
      .addra(enigma_letter_count),   // Port A address bus,
      .dina(enigma_data_out),     // Port A RAM input data
      .wea(enigma_data_valid),       // Port A write enable
      //reading port:
      .addrb(ir_letter_count),   // Port B address bus,
      .doutb(letter_buffer_out),    // Port B RAM output data,
      .douta(),   // never read from this side
      .dinb(),     // never write to this side
      .web(1'b0),       // Port B write enable
      .ena(1'b1),       // Port A RAM Enable
      .enb(1'b1),       // Port B RAM Enable,
      .rsta(1'b0),     // Port A output reset 
      .rstb(1'b0),     // Port B output reset
      .regcea(1'b1),   // Port A output register enable
      .regceb(1'b1)    // Port B output register enable
      );


  logic [10:0] display_letter_count;
  logic [4:0] display_letter_out;

   // Display BRAM 
  xilinx_true_dual_port_read_first_2_clock_ram #(
      .RAM_WIDTH(5),
      .RAM_DEPTH(1024),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE")) letter_buffer_display_ram (
      .clka(clk_100_passthrough),     // Clock 
      //writing port:
      .addra(enigma_letter_count),   // Port A address bus,
      .dina(enigma_data_out),     // Port A RAM input data
      .wea(enigma_data_valid),       // Port A write enable
      //reading port:
      .addrb(display_letter_count-1),   // Port B address bus
      .doutb(display_letter_out),    // Port B RAM output data,
      .clkb(clk_pixel),
      .douta(),   // never read from this side
      .dinb(),     // never write to this side
      .web(1'b0),       // Port B write enable
      .ena(1'b1),       // Port A RAM Enable
      .enb(1'b1),       // Port B RAM Enable,
      .rsta(1'b0),     // Port A output reset 
      .rstb(1'b0),     // Port B output reset
      .regcea(1'b1),   // Port A output register enable
      .regceb(1'b1)    // Port B output register enable
      );

  
  always_ff @(posedge clk_pixel) begin
    if(sys_rst) begin
      display_letter_count <= 0;
    end
    else begin
      // increment if the button is pressed
      if (debounced_output && ! prev_output) begin
        display_letter_count <= display_letter_count == 1023 ? 0 : display_letter_count + 1;
      end
    end
  end


  always_ff @(posedge clk_100_passthrough) begin
    last_ir_busy_out <= ir_busy_out;
    last_enigma_data_valid <= enigma_data_valid;
    letter_buffer_valid_pipe <= {letter_buffer_valid_pipe[0], letter_buffer_valid};
    if(sys_rst) begin
      ir_letter_count <= 0;
      enigma_letter_count <= 0;
    end
    else begin
      // if one letter has been transmitted, move on to read the next letter
      if (!ir_busy_out && last_ir_busy_out) begin
        ir_letter_count <= ir_letter_count == 1023 ? 0 : ir_letter_count + 1;
      end
      // update to write in the next letter address every time a letter is output from the enigma module
      if (enigma_data_valid && ! last_enigma_data_valid) begin
        letter_buffer_valid <= 1; // only want letter buffer valid once for the ir transmitter
        enigma_letter_count <= enigma_letter_count == 1023 ? 0 : enigma_letter_count + 1;
      end
      else if(!ir_busy_out) begin // otherwise hold it until IR not busy
        letter_buffer_valid <= 0;
      end
    end
    
  end

  // for debugging:
  // 7-segment display-related concepts:
  logic [31:0] val_to_display; //either the spi data or the btn_count data (default)
  logic [6:0] ss_c; //used to grab output cathode signal for 7s leds
 
  seven_segment_controller mssc(.clk_in(clk_100_passthrough),
                                .rst_in(sys_rst),
                                .val_in(val_to_display),
                                .cat_out(ss_c),
                                .an_out({ss0_an, ss1_an}));
  assign ss0_c = ss_c; //control upper four digit's cathodes
  assign ss1_c = ss_c; //same as above but for lower four digits

    always_ff @(posedge clk_100_passthrough)begin
    val_to_display <= sys_rst?0: letter_buffer_valid_pipe[1] ?
      {27'b0, letter_buffer_out} : val_to_display;
    end
  



endmodule // top_level


`default_nettype wire