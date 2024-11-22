`timescale 1ns / 1ps
`default_nettype none
module ir_transmitter
       #( parameter SBD  = 240_000, //sync burst duration
          parameter BSD = 60_000, //bit burst duration
          parameter BBD0 = 60_000, //bit silence duration (for 0)
          parameter BBD1 = 120_000, //bit silence duration (for 1)
          parameter MARGIN = 20_000, //The +/- of your signals
          parameter MESSAGE_LENGTH = 30
          // the duration is in terms of number of cycles per each duration
        )
        ( input wire clk_in, //clock in (100MHz)
          input wire rst_in, //reset in
          input wire data_valid_in, //data valid signal
          input wire [MESSAGE_LENGTH-1:0] data_in, // input letters captured 
          output logic busy_out, //indicator that is busy
          output logic signal_out// signal indicating if the LED is high or low on this clock cycle
        );
    logic [31:0] cur_cycle_counter;
    logic [$clog2(MESSAGE_LENGTH):0] cur_bit_counter;
    logic [MESSAGE_LENGTH-1:0] cur_data;

    // logic signal_value;
    logic signal_high;
    logic signal_low;
    localparam DC_LENGTH = 1280;
    
    assign signal_low = 0;


    pwm ir_pwm (.clk_in(clk_in),
            .rst_in(rst_in),
            .dc_in(DC_LENGTH),
            .sig_out(signal_high));
    
    typedef enum {IDLE = 0, SB = 1, SS = 2, BS = 3, BB0 = 4, BB1 = 5, EOM = 6} ir_state;
    ir_state state; //state of system

    
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            busy_out <= 0;
            state <= IDLE;
            cur_cycle_counter <= 0;
            cur_bit_counter <= 0;
            signal_out <= signal_low;
            cur_data = 0;
        end
        else begin
            case (state)
                IDLE : begin
                    if (data_valid_in) begin
                        cur_data <= data_in;
                        busy_out <= 1;
                        state <= SB;
                        cur_cycle_counter <= 0;
                        signal_out <= signal_high;
                    end
                    else begin
                        signal_out <= 0;
                    end
                end

                // sync burst
                SB : begin
                    if (cur_cycle_counter < SBD) begin
                        cur_cycle_counter <= cur_cycle_counter + 1;
                        signal_out <= signal_high;
                    end
                    else begin
                        cur_cycle_counter <= 0;
                        state <= BS;
                        signal_out <= signal_low;
                    end
                end

                // bit silence 0/1
                BS : begin
                    if (cur_cycle_counter < BSD) begin
                        cur_cycle_counter <= cur_cycle_counter + 1;
                        signal_out <= signal_low;
                    end
                    else begin
                        cur_cycle_counter <= 0;
                        cur_bit_counter <= cur_bit_counter + 1;
                        state <= cur_data[MESSAGE_LENGTH-cur_bit_counter-1]  == 0 ? BB0 : BB1; // MSB first
                        signal_out <= signal_high;
                    end
                end

                // bit burst 0
                BB0 :  begin
                    if (cur_cycle_counter < BBD0) begin
                        cur_cycle_counter <= cur_cycle_counter + 1;
                        signal_out <= signal_high;
                    end
                    else begin
                        cur_cycle_counter <= 0;
                        state <= cur_bit_counter == MESSAGE_LENGTH ? EOM : BS;
                        signal_out <= signal_low;
                    end

                end

                // bit burst 1
                BB1 : begin
                    if (cur_cycle_counter < BBD1) begin
                        cur_cycle_counter <= cur_cycle_counter + 1;
                        signal_out <= signal_high;
                    end
                    else begin
                        cur_cycle_counter <= 0;
                        state <= cur_bit_counter == MESSAGE_LENGTH ? EOM : BS;
                        signal_out <= signal_low;
                    end

                end

                // end of message single cycle to return to idle 
                EOM : begin

                    if (cur_cycle_counter < BSD) begin
                        cur_cycle_counter <= cur_cycle_counter + 1;
                        signal_out <= signal_low;
                    end
                    else begin
                        cur_cycle_counter <= 0;
                        cur_bit_counter <= cur_bit_counter + 1;
                        state <= IDLE;
                        signal_out <= signal_low;
                        busy_out <= 0;
                        cur_bit_counter <= 0;
                        cur_cycle_counter <= 0;
                    end
                end


            endcase
        end

    end
        
endmodule
`default_nettype none