# Questa/ModelSim run script
vlib work
vlog -sv -f filelist.f
vsim -c tb_top -do "run -all; quit"
