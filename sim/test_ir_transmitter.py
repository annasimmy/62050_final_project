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
    """cocotb test for ir_transmitter"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 2, rising=False)

    dut.rst_in.value = 0
    dut.data_valid_in.value = 1
    dut.data_in = 0b1010_1010
    await ClockCycles(dut.clk_in, 400, rising=False)


def is_runner():
    """IR Transmitter Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "ir_transmitter.sv"]
    # sources += [proj_path / "hdl" / "xilinx_true_dual_port_read_first_1_clock_ram.v"]
    build_test_args = ["-Wall"]
    parameters = {'SBD' : 90, 'SSD' : 45, 'BBD' : 6, 'BSD0' : 6 , 'BSD1' : 16, 'MESSAGE_LENGTH' : 8}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="ir_transmitter",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="ir_transmitter",
        test_module="test_ir_transmitter",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()
