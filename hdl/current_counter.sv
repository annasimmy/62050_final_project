// `timescale 1ns / 1ps
// `default_nettype none // prevents system from inferring an undeclared logic (good practice)
 
// module current_counter
//   ( input wire clk_in, //clock in
//     input wire rst_in, //reset in
//     input wire signal_in, //signal to be monitored
//     output logic [31:0] tally_out //tally of how many cycles signal in has been at its current value
//   );
//     logic last_in;

//     always_ff @(posedge clk_in) begin
//         last_in <= signal_in;

//         if (rst_in) begin
//             tally_out <= 32'b0; // assign to 0 on the reset
//         end
//         else begin
//             // tally_out is one cycle delayed compared to signal_in
//             // so that we can know how long a stretch of 1s or 0s was after we know it has ended
//             if (signal_in == last_in) begin
//                 tally_out <= tally_out + 1;
//             end
//             else begin
//                 tally_out <= 32'b0;
//             end
//         end
//     end
// endmodule
 
// `default_nettype wire