# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
FST ?= -fst # Use more efficient FST format
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
# every .sv in info.yaml's source_files; the .svh headers are found through -I$(SRC_DIR)
PROJECT_SOURCES = aquafuse_icg.sv aquafuse_lat.sv aquafuse_wgate.sv aquafuse_sel.sv aquafuse_sensor_if.sv aquafuse_stem_accum.sv \
	aquafuse_conv_stage.sv aquafuse_rom_stem.sv aquafuse_rom_b1.sv aquafuse_rom_b2.sv \
	aquafuse_rom_obj.sv aquafuse_bg_fifo.sv aquafuse_bg_store.sv aquafuse_bg_block.sv \
	aquafuse_temporal_head.sv tt_um_aquafuse_stream12c.sv

ifneq ($(GATES),yes)

# RTL simulation. Icarus 12 rejects one expression in aquafuse_temporal_head.sv (an unsized divisor
# inside a concatenation), so the RTL run uses compat/aquafuse_temporal_head.sv, the same arithmetic
# with a sized divisor. The file that is HARDENED is ../src/aquafuse_temporal_head.sv, untouched.
SIM_BUILD				= sim_build/rtl
# Icarus simulates this RTL at about 260 s per frame (VPS, 19 Oct 2026), so the 32-frame clip plus the config test
# would run for 3-5 hours against GitHub's 6-hour job limit. 12 frames reach the first alarm (frame 3) and the
# wake bit's rising edge (frame 5). All 32 frames in RTL are covered by the project's Verilator equivalence run, and
# the gate-level job below keeps all 32. Set AQUAFUSE_FRAMES=32 for the full RTL clip.
export AQUAFUSE_FRAMES ?= 12
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(filter-out aquafuse_temporal_head.sv,$(PROJECT_SOURCES)))
VERILOG_SOURCES += $(PWD)/compat/aquafuse_temporal_head.sv
# The compat copy must stay the hardened file except for its two sized divisors; stop if it has drifted (it did once,
# from ser3 to ser12, and the RTL test then simulated a head the chip does not have).
COMPAT_DRIFT := $(shell diff $(SRC_DIR)/aquafuse_temporal_head.sv $(PWD)/compat/aquafuse_temporal_head.sv | grep -c '^[<>]')
ifneq ($(COMPAT_DRIFT),8)
$(error test/compat/aquafuse_temporal_head.sv has drifted from src/ ($(COMPAT_DRIFT) changed lines, expected 8))
endif

else

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
# GF180 cell models, as in TinyTapeout/ttgf-verilog-template (these were still the SKY130 ones), except that the cell
# models are a copy with 1 ns clock-to-Q on every flop and latch: the PDK's are zero-delay, and with this part's gated
# clocks a zero-delay netlist simulation races (see gl_models_dly.sh). The copy is checked to have changed something.
GF_MODELS := $(PDK_ROOT)/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog
GF_MODELS_DLY := $(shell bash $(PWD)/gl_models_dly.sh $(GF_MODELS) $(PWD)/sim_build/gf180_models_dly.v)
ifeq ($(GF_MODELS_DLY),)
$(error gl_models_dly.sh failed to write the delayed GF180 cell models)
endif
VERILOG_SOURCES += $(GF_MODELS)/primitives.v
VERILOG_SOURCES += $(GF_MODELS_DLY)

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# List test modules to run, separated by commas and without the .py suffix:
COCOTB_TEST_MODULES = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
