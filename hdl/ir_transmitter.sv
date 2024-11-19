`timescale 1ns / 1ps
`default_nettype none
module ir_transmitter
       #( parameter SBD  = 900_000, //sync burst duration
          parameter SSD  = 450_000, //sync silence duration
          parameter BBD = 60_000, //bit burst duration
          parameter BSD0 = 60_000, //bit silence duration (for 0)
          parameter BSD1 = 160_000, //bit silence duration (for 1)
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
    
    typedef enum {IDLE = 0, SB = 1, SS = 2, BB = 3, BS0 = 4, BS1 = 5, EOM = 6} ir_state;
    ir_state state; //state of system!


// TODO 40kHz clock cycle use pulses
    
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            busy_out <= 0;
            state <= IDLE;
            cur_cycle_counter <= 0;
            cur_bit_counter <= 0;
            signal_out <= 0;
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
                        signal_out <= 1;
                    end
                    else begin
                        signal_out <= 0;
                    end
                end

                // synch burst
                SB : begin
                    if (cur_cycle_counter < SBD) begin
                        cur_cycle_counter <= cur_cycle_counter + 1;
                        signal_out <= 1;
                    end
                    else begin
                        cur_cycle_counter <= 0;
                        state <= SS;
                        signal_out <= 0;
                    end
                end

                // synch silence
                SS : begin
                    if (cur_cycle_counter < SSD) begin
                        cur_cycle_counter <= cur_cycle_counter + 1;
                        signal_out <= 0;
                    end
                    else begin
                        cur_cycle_counter <= 0;
                        state <= BB;
                        signal_out <= 1;
                    end
                end

                // bit burst 0/1
                BB : begin
                    if (cur_cycle_counter < BBD) begin
                        cur_cycle_counter <= cur_cycle_counter + 1;
                        signal_out <= 1;
                    end
                    else begin
                        cur_cycle_counter <= 0;
                        cur_bit_counter <= cur_bit_counter + 1;
                        state <= cur_data[MESSAGE_LENGTH-cur_bit_counter-1]  == 0 ? BS0 : BS1; // MSB first
                        signal_out <= 0;
                    end
                end

                // bit silence 0
                BS0 :  begin
                    if (cur_cycle_counter < BSD0) begin
                        cur_cycle_counter <= cur_cycle_counter + 1;
                        signal_out <= 0;
                    end
                    else begin
                        cur_cycle_counter <= 0;
                        state <= cur_bit_counter == MESSAGE_LENGTH ? EOM : BB;
                        signal_out <= 1;
                    end

                end

                // bit silence 1
                BS1 : begin
                    if (cur_cycle_counter < BSD1) begin
                        cur_cycle_counter <= cur_cycle_counter + 1;
                        signal_out <= 0;
                    end
                    else begin
                        cur_cycle_counter <= 0;
                        state <= cur_bit_counter == MESSAGE_LENGTH ? EOM : BB;
                        signal_out <= 1;
                    end

                end

                // end of message single cycle to return to idle 
                EOM : begin
                    busy_out <= 0;
                    state <= IDLE;
                    cur_bit_counter <= 0;
                    cur_cycle_counter <= 0;
                    signal_out <= 0;
                end


            endcase
        end

    end
        
endmodule
`default_nettype none