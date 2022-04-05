database -open dump -shm
probe -create spmd_testbench.testbench.DUT -depth all -all -shm -database dump
run
exit
