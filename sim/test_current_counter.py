import cocotb
import os
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner


@cocotb.test()
async def test_a(dut):
    """cocotb test for current_counter"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 1

    dut.signal_in.value = 0
    await ClockCycles(dut.clk_in, 3, rising=False)
    dut.rst_in.value = 0
    for i in range (25):
        await  FallingEdge(dut.clk_in)
        dut._log.info(f"Current counter: {dut.tally_out.value}")
    await RisingEdge(dut.clk_in)
    dut.signal_in.value = 1;
    for i in range (10):
        await  FallingEdge(dut.clk_in)
        dut._log.info(f"Current counter: {dut.tally_out.value}")


def is_runner():
    """Current Counter Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "current_counter.sv"]
    # sources += [proj_path / "hdl" / "xilinx_true_dual_port_read_first_1_clock_ram.v"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="current_counter",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="current_counter",
        test_module="test_current_counter",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()
