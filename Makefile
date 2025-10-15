BUILD_DIR := ./build
SRC_DIR := ./src
TB_DIR := ./tb

SRCS = $(shell find $(SRC_DIR) -name '*.v')
TBS = $(shell find $(TB_DIR) -name '*.v')

TARGETS := $(patsubst $(TB_DIR)/%.v,$(BUILD_DIR)/%,$(TBS))

INC_DIRS := ./include

IVERILOG_FLAGS := $(addprefix -I,$(INC_DIRS))

$(BUILD_DIR)/%: $(TB_DIR)/%.v $(SRCS)
	mkdir -p $(dir $@)
	iverilog $(IVERILOG_FLAGS) -o $@ $< $(SRCS) 

all: $(TARGETS)

clean:
	rm -rf $(BUILD_DIR)

run: $(BUILD_DIR)/$(TB)
	@if [ -z "$(TB)" ]; then \
	    echo "Usage: make run TB=<testbench_name>"; \
	    exit 1; \
	fi
	vvp $<

wave: $(BUILD_DIR)/$(TB)
	@if [ -z "$(TB)" ]; then \
	    echo "Usage: make wave TB=<testbench_name>"; \
	    exit 1; \
	fi
	vvp $<
	gtkwave dump.vcd

.PHONY: clean run wave
