# Simulator selection — adjust for your tool
# For Icarus Verilog (open-source):
SIM = iverilog
RUN = vvp

# For VCS:
# SIM = vcs
# For Questa/ModelSim:
# SIM = vlog/vsim

.PHONY: all compile run clean

all: compile run

compile:
	$(SIM) -g2012 -I../tb -o uart_tb.vvp -f filelist.f

run:
	$(RUN) uart_tb.vvp | tee ../results/test_log.txt

clean:
	rm -f uart_tb.vvp uart_tb.vcd
	rm -f ../results/test_log.txt
