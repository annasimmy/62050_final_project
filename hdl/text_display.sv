`timescale 1ns / 1ps
`default_nettype none

module text_display (
    input wire clk_in,
    input wire clk_pixel,
    input wire clk_5x,
    input wire sys_rst_pixel,
    input wire data_valid_in,
    input wire [4:0] data_in,
    output logic tmds_red_out,
    output logic tmds_green_out,
    output logic tmds_blue_out
    );



    logic [4:0] text [511:0];
    logic [8:0] counter;

    always_ff @(posedge clk_in) begin
        if(sys_rst_pixel) begin
            counter <= 0;
            for(int i = 0; i < 512; i = i + 1) begin
                text[i] <= 26;
            end
        end else if(data_valid_in) begin
            text[counter] <= data_in;
            if(counter == 511) begin
                counter <= 0;
            end else begin
                counter <= counter + 1;
            end
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


    logic [9:0] tmds_10b [0:2];

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
         .tmds_out(tmds_red_out));
    tmds_serializer green_ser(
         .clk_pixel_in(clk_pixel),
         .clk_5x_in(clk_5x),
         .rst_in(sys_rst_pixel),
         .tmds_in(tmds_10b[1]),
         .tmds_out(tmds_green_out));
    tmds_serializer blue_ser(
         .clk_pixel_in(clk_pixel),
         .clk_5x_in(clk_5x),
         .rst_in(sys_rst_pixel),
         .tmds_in(tmds_10b[0]),
         .tmds_out(tmds_blue_out));
endmodule
