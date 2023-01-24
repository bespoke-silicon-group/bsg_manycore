database -open dump -shm
probe -create spmd_testbench.testbench.fi1.DUT -depth all -all -shm -database dump
run
exit
