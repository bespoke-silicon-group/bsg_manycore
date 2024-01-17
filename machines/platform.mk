
BSG_PLATFORM ?= vcs
# Default Machine ISA is Vanilla. This can be modified to any of the supported ISA in the repository bsg_manycore_ISA
# Note that you would have to sync the above repository as well to use another ISA
# You can change the below to modify the machine built
BSG_MACHINE_ISA ?= VANILLA
# BSG_MACHINE_ISA ?= RISCV

ifeq ($(BSG_PLATFORM),vcs)
DEFAULT_MACHINES = pod_1x1 pod_1x1_hbm2 pod_4x4 pod_4x4_hbm2
BSG_SIM_BASE = simv
else ifeq ($(BSG_PLATFORM),verilator)
DEFAULT_MACHINES = pod_1x1_4X2Y
BSG_SIM_BASE = simsc
else ifeq ($(BSG_PLATFORM),xcelium)
DEFAULT_MACHINES = pod_1x1 pod_1x1_hbm2 pod_4x4 pod_4x4_hbm2
BSG_SIM_BASE = simx
endif

