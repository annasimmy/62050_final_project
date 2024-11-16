// `timescale 1ns / 1ps
// `default_nettype none
// module ir_decoder
//        #( parameter SBD  = 900_000, //sync burst duration
//           parameter SSD  = 450_000, //sync silence duration
//           parameter BBD = 60_000, //bit burst duration
//           parameter BSD0 = 60_000, //bit silence duration (for 0)
//           parameter BSD1 = 160_000, //bit silence duration (for 1)
//           parameter MARGIN = 20_000 //The +/- of your signals
//           // the duration is in terms of number of cycles per each duration
//         )
//         ( input wire clk_in, //clock in (100MHz)
//           input wire rst_in, //reset in
//           input wire signal_in, //signal in
//           output logic [31:0] code_out, //where to place 32 bit code once captured TODO change to 30 bit
//           output logic new_code_out, //single-cycle indicator that new code is present!
//           output logic [2:0] error_out, //output error codes for debugging
//           output logic [3:0] state_out //current state out (helpful for debugging)
//         );

//   logic last_signal;
//   logic [31:0] signal_counter;
//   typedef enum {IDLE=0, SL=1, SH=2, DL=3, DH=4, F0=5, F1=6, CHECK=7,DATA=8} ir_state;
 
//   current_counter mcc( .clk_in(clk_in),
//                         .rst_in(rst_in),
//                         .signal_in(signal_in),
//                         .tally_out(signal_counter));
 
//   ir_state state; //state of system!
//   logic [31:0] data_buffer; // buffer for the 32 bits of data
//   logic [5:0] num_bits_so_far;
 
//   assign state_out = state;
 
//   always_ff @(posedge clk_in)begin
//     if (rst_in)begin
//       state <= IDLE;
//       code_out <= 0;
//       new_code_out <= 0;
//       error_out <=0;
//       data_buffer <= 0;
//       num_bits_so_far <= 0;
//     end else begin
//       case (state)
//       // TODO do we do in terms of the current signal or the last signal
//         IDLE : begin
//           state <= signal_in == 1'b0 ? SL : IDLE; // move to sync low if a burst of light is detected
//           data_buffer <= 0; // clear the data buffer
//           num_bits_so_far <= 0;
//           code_out <= 0;
//           new_code_out <= 0;
//           error_out <= 0;
//         end

//         // sync low
//         SL : begin
//           // waiting to see if its the appropriate length
//           state <= signal_in == 1'b1 
//                     ? (signal_counter >= (SBD - MARGIN) && signal_counter <= (SBD + MARGIN)) 
//                         ? SH // appropriate length go to sync high
//                         : IDLE // signal not long enough, go to IDLE
//                     : signal_counter > (SBD + MARGIN)
//                       ? IDLE // signal too long
//                       : SL; // signal still low
//         end

//         // sync high
//         SH : begin
//           state <= signal_in == 1'b0
//                     ? (signal_counter >= (SSD - MARGIN) && signal_counter <= (SSD + MARGIN)) 
//                         ? DL // appropriate length go to "data low"
//                         : IDLE // signal not long enough, go to IDLE
//                     : signal_counter > (SSD + MARGIN)
//                       ? IDLE // signal too long
//                       : SH; // signal still high
//         end

//         DL : begin
//           state <= signal_in == 1'b1
//                   ? (signal_counter >= (BBD - MARGIN) && signal_counter <= (BBD + MARGIN)) 
//                         ? DH // appropriate length go to "data high"
//                         : IDLE // signal not long enough, go to IDLE
//                     : signal_counter > (BBD + MARGIN)
//                       ? IDLE // signal too long
//                       : DL; // signal still low
//         end

//         DH : begin
//           state <= signal_in == 1'b0
//                   ? (signal_counter >= (BSD0 - MARGIN) && signal_counter <= (BSD0 + MARGIN)) 
//                         ? F0 // appropriate length for a '0' go to "F0"
//                         : (signal_counter >= (BSD1 - MARGIN) && signal_counter <= (BSD1 + MARGIN)) 
//                           ? F1 // appropriate length for a '1' go to "F1"
//                           : IDLE// signal not the right length, go to IDLE
//                     : signal_counter > (BSD1 + MARGIN)
//                       ? IDLE // signal too long
//                       : DH; // signal still high
//         end

//         F0 : begin
//           data_buffer <= {data_buffer[30:0], 1'b0}; // TODO make sure this is msb
//           num_bits_so_far <= num_bits_so_far + 1;
//           state <= CHECK;
//         end

//         F1 : begin
//           data_buffer <= {data_buffer[30:0], 1'b1};
//           num_bits_so_far <= num_bits_so_far + 1;
//           state <= CHECK;
//         end

//         CHECK : begin
//           // check if there's been 32 bits into the data buffer
//           state <= num_bits_so_far == 32 ? DATA : DL; 
//         end

//         DATA : begin
//           new_code_out <= 1;
//           code_out <= data_buffer;
//           state <= IDLE;
//         end
//       endcase
//     end
//   end
 
// endmodule
// `default_nettype none