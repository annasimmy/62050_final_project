`timescale 1ns / 1ps
`default_nettype none

module enigma_display (
    input wire clk_in,
    input wire clk_pixel,
    input wire sys_rst_pixel,
    input wire [4:0] orig_letter_in,
    input wire [4:0] code_letter_in,
    output logic [7:0] red_out,
    output logic [7:0] green_out,
    output logic [7:0] blue_out,
    output logic hsync_hdmi_out,
    output logic vsync_hdmi_out,
    output logic active_draw_hdmi_out
    );

    localparam logic [4:0] letter_map [25:0] = '{
        17, 23, 5, 18, 20, 26, 21, 9, 15,
        1, 19, 4, 6, 7, 8, 10, 11,
        16, 25, 24, 3, 22, 2, 14, 13, 12
    };


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

    logic [10:0] hcount_pipe [3:0];
    logic [9:0] vcount_pipe [3:0];
    logic [10:0] hcount_left_pipe [3:0];
    logic [9:0] vcount_up_pipe [3:0];
    logic [10:0] hcount_pipe_2 [3:0];
    logic shift_pipe   [6:0];
    logic          hsync_hdmi_pipe [13:0];
    logic          vsync_hdmi_pipe [13:0];
    logic          active_draw_hdmi_pipe [13:0];

    logic [10:0] letter_hcount;
    logic [9:0] letter_vcount;
    logic [10:0] letter_x;
    logic [9:0] letter_y;
    logic [4:0] letter_letter;
    
    logic [14:0] x_dist;
    logic [14:0] y_dist;
    logic [14:0] dist_sq;

    logic [7:0] red, green, blue;

    always_ff @(posedge clk_pixel)begin
        hcount_pipe[0] <= hcount_hdmi;
        vcount_pipe[0] <= vcount_hdmi;
        if((vcount_hdmi <= 210 && vcount_hdmi >= 110) || (vcount_hdmi <= 570 && vcount_hdmi >= 470)) begin
            vcount_up_pipe[0] <= 1;
            hcount_left_pipe[0] <= 0;
            shift_pipe[0] <= (vcount_hdmi > 210) ? 1 : 0;
            if(hcount_hdmi >= 70) begin
                hcount_pipe_2[0] <= hcount_hdmi - 70;
            end else begin
                hcount_pipe_2[0] <= hcount_hdmi;
            end
        end else if(vcount_hdmi >= 310 && vcount_hdmi <= 370) begin
            vcount_up_pipe[0] <= 3;
        end else if(vcount_hdmi <= 670) begin
            if(vcount_hdmi <= 110 || (vcount_hdmi >= 370 && vcount_hdmi <= 470)) begin
                vcount_up_pipe[0] <= 0;
            end else begin
                vcount_up_pipe[0] <= 2;
            end
            shift_pipe[0] <= (vcount_hdmi > 310) ? 1 : 0;
            if(hcount_hdmi >= 1120) begin
                hcount_left_pipe[0] <= 8;
                hcount_pipe_2[0] <= hcount_hdmi - 1120;
            end else begin
                hcount_left_pipe[0] <= 0;
                hcount_pipe_2[0] <= hcount_hdmi;
            end
        end else begin
            vcount_up_pipe[0] <= 3;
        end
        
        hsync_hdmi_pipe[0] <= hsync_hdmi;
        vsync_hdmi_pipe[0] <= vsync_hdmi;
        active_draw_hdmi_pipe[0] <= active_draw_hdmi;
        for (int i = 1; i <= 13; i = i+1)begin
            hsync_hdmi_pipe[i] <= hsync_hdmi_pipe[i - 1];
            vsync_hdmi_pipe[i] <= vsync_hdmi_pipe[i - 1];
            active_draw_hdmi_pipe[i] <= active_draw_hdmi_pipe[i - 1];
        end
        
        for (int i = 1; i <= 6; i = i+1)begin
            shift_pipe[i] <= shift_pipe[i - 1];
        end

        for (int i = 1; i <= 3; i = i+1)begin
            hcount_pipe[i] <= hcount_pipe[i - 1];
            vcount_pipe[i] <= vcount_pipe[i - 1];
            if(hcount_pipe_2[i - 1] >= (1120 >> i)) begin
                hcount_left_pipe[i] <= hcount_left_pipe[i - 1] + (8 >> i);
                hcount_pipe_2[i] <= hcount_pipe_2[i - 1] - (1120 >> i);
            end else begin
                hcount_left_pipe[i] <= hcount_left_pipe[i - 1];
                hcount_pipe_2[i] <= hcount_pipe_2[i - 1];
            end
            vcount_up_pipe[i] <= vcount_up_pipe[i - 1];
        end

        letter_hcount <= hcount_pipe[3];
        letter_vcount <= vcount_pipe[3];
        if(vcount_up_pipe[3] == 0) begin
            letter_letter <= 25 - hcount_left_pipe[3];
        end else if(vcount_up_pipe[3] == 1) begin
            letter_letter <= 25 - hcount_left_pipe[3] - 9;
        end else if(vcount_up_pipe[3] == 2) begin
            letter_letter <= 25 - hcount_left_pipe[3] - 17;
        end else begin
            letter_letter <= 26;
        end
        if(vcount_up_pipe[3] == 1) begin
            letter_x <= 130 + hcount_left_pipe[3] * 140;
        end else begin
            letter_x <= 60 + hcount_left_pipe[3] * 140;
        end
        letter_y <= 40 + vcount_up_pipe[3] * 100 + 360 * shift_pipe[3];

        hsync_hdmi_out <= hsync_hdmi_pipe[13];
        vsync_hdmi_out <= vsync_hdmi_pipe[13];
        active_draw_hdmi_out <= active_draw_hdmi_pipe[13];
        // hsync_hdmi_out <= hsync_hdmi_pipe[0];
        // vsync_hdmi_out <= vsync_hdmi_pipe[0];
        // active_draw_hdmi_out <= active_draw_hdmi_pipe[0];

        if(letter_hcount > letter_x + 22) begin
            x_dist <= letter_hcount - letter_x - 22;
        end else begin
            x_dist <= letter_x + 22 - letter_hcount;
        end

        if(letter_vcount > letter_y + 23) begin
            y_dist <= letter_vcount - letter_y - 23;
        end else begin
            y_dist <= letter_y + 23 - letter_vcount;
        end
        dist_sq <= x_dist * x_dist + y_dist * y_dist;
        
        if(dist_sq < 1225 && letter_letter < 26) begin
            if(red > 200) begin
                red_out <= shift_pipe[6] ? ((letter_map[letter_letter] == orig_letter_in) ? 50 : 200) : 200;
            end else begin
                red_out <= red;
            end
            if(green > 200) begin
                green_out <= shift_pipe[6] ? ((letter_map[letter_letter] == orig_letter_in) ? 50 : 200) : 200;
            end else begin
                green_out <= green;
            end
            if(blue > 200) begin
                blue_out <= shift_pipe[6] ? 
                    ((letter_map[letter_letter] == orig_letter_in) ? 50 : 200) : 
                    ((letter_map[letter_letter] == code_letter_in) ? 0 : 200);
            end else begin
                blue_out <= blue;
            end
        end else begin
            red_out <= 0;
            green_out <= 0;
            blue_out <= 0;
        end
        // red_out <= red;
        // green_out <= green;
        // blue_out <= blue;
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
        .letter(letter_map[letter_letter]),
        .red_out(red),
        .green_out(green),
        .blue_out(blue));

endmodule
