`timescale 1ns / 1ps
`default_nettype none

module text_display (
    input wire clk_in,
    input wire clk_pixel,
    input wire sys_rst_pixel,
    input wire data_valid_in,
    input wire [4:0] data_in,
    input wire [1:0] scroll_dir_in,
    output logic [7:0] red_out,
    output logic [7:0] green_out,
    output logic [7:0] blue_out,
    output logic hsync_hdmi_out,
    output logic vsync_hdmi_out,
    output logic active_draw_hdmi_out
    );

    logic [10:0] counter;
    logic [4:0] hold_data_in;
    logic [8:0] scroll_lines;

    always_ff @(posedge clk_in) begin
        if(sys_rst_pixel) begin
            counter <= 0;
        end else begin
            if(data_valid_in) begin
                hold_data_in <= data_in;
                if(counter == 1024) begin
                    counter <= 1;
                end else begin
                    counter <= counter + 1;
                end
            end
        end
    end
    
    always_ff @(posedge clk_pixel) begin
        if(sys_rst_pixel) begin
            scroll_lines <= 0;
        end else begin
            if(scroll_dir_in == 1) begin
                if(scroll_lines != 16) begin
                    scroll_lines <= scroll_lines + 1;
                end
            end else if(scroll_dir_in == 2) begin
                if(scroll_lines != 0) begin
                    scroll_lines <= scroll_lines - 1;
                end
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

    logic [10:0] hcount_pipe [4:0];
    logic [9:0] vcount_pipe [4:0];
    logic [10:0] hcount_left_pipe [4:0];
    logic [9:0] vcount_up_pipe [4:0];
    logic [10:0] hcount_pipe_2 [4:0];
    logic [9:0] vcount_pipe_2 [4:0];
    logic          hsync_hdmi_pipe [11:0];
    logic          vsync_hdmi_pipe [11:0];
    logic          active_draw_hdmi_pipe [11:0];

    logic [10:0] letter_hcount;
    logic [9:0] letter_vcount;
    logic [10:0] letter_x;
    logic [9:0] letter_y;

    logic [4:0] letter_letter;
    logic [4:0] letter_letter2;
    logic [9:0] addra;
    logic [9:0] addra2;

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
        for (int i = 1; i <= 11; i = i+1)begin
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
        vcount_up_pipe[4] <= vcount_up_pipe[3];

        
        letter_hcount <= hcount_pipe[4];
        letter_vcount <= vcount_pipe[4];
        letter_x <= hcount_left_pipe[4] * 40;
        letter_y <= vcount_up_pipe[4] * 45;

        addra <= hcount_left_pipe[4] + (vcount_up_pipe[4] << 5) + (scroll_lines << 5);
        addra2 <= addra;
        letter_letter2 <= letter_letter;

        hsync_hdmi_out <= hsync_hdmi_pipe[10];
        vsync_hdmi_out <= vsync_hdmi_pipe[10];
        active_draw_hdmi_out <= active_draw_hdmi_pipe[10];
    end
    

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

    
    xilinx_true_dual_port_read_first_2_clock_ram
        #(.RAM_WIDTH(5),
          .RAM_DEPTH(1024)) text_bram(
          // PORT A
          .addra(addra2),
          .dina(0), // we only use port A for reads!
          .clka(clk_pixel),
          .wea(1'b0), // read only
          .ena(1'b1),
          .rsta(sys_rst_pixel),
          .regcea(1'b1),
          .douta(letter_letter),
          // PORT B
          .addrb(counter - 1),
          .dinb(hold_data_in),
          .clkb(clk_in),
          .web(1'b1), // write always
          .enb(1'b1),
          .rstb(sys_rst_pixel),
          .regceb(1'b1),
          .doutb() // we only use port B for writes!
          );

    // width 228, height 225 for 6x5 grid
    // width 38, height 45 per letter
    // if I do 40x45, that perfectly fits 32x16 letters in a 1280x720 display
    image_sprite #(
        .WIDTH(228),
        .HEIGHT(225))
    letter_sprite (
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .hcount_in(letter_hcount),  
        .vcount_in(letter_vcount),  
        .x_in(letter_x),
        .y_in(letter_y),
        .letter(letter_letter2),
        .red_out(red_out),
        .green_out(green_out),
        .blue_out(blue_out));

endmodule
