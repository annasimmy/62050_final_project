import cocotb
import os
import random
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

@cocotb.test()
async def test_a(dut):
    """cocotb test for seven segment controller"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_100mhz, 10, units="ns").start())
    dut._log.info("Holding reset...")
    await ClockCycles(dut.clk_100mhz, 3)
    await  FallingEdge(dut.clk_100mhz)
    dut._log.info("setting reset to 0")
    dut.hcount_hdmi.value = 100
    dut.vcount_hdmi.value = 100
    await ClockCycles(dut.clk_100mhz, 300)

def ssc_runner():
    """Simulate the counter using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "top_level.sv"]
    build_test_args = ["-Wall"]
    #'''INPUT_CLOCK_FREQ':100000000, 'BAUD_RATE':10000000'''
    parameters = {} #setting parameter to a short amount (for testing)
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="top_level",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="top_level",
        test_module="test_top",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    ssc_runner()