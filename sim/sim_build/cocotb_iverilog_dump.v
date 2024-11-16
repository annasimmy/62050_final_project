module cocotb_iverilog_dump();
initial begin
    $dumpfile("C:/Users/kevin/6205_psets/62050_final_project/sim/sim_build/top_level.fst");
    $dumpvars(0, top_level);
end
endmodule
