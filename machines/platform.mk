
BSG_PLATFORM ?= verilator

ifeq ($(BSG_PLATFORM),vcs)
DEFAULT_MACHINES = pod_1x1 pod_1x1_hbm2 pod_4x4 pod_4x4_hbm2
BSG_SIM_BASE = simv
else ifeq ($(BSG_PLATFORM),verilator)
DEFAULT_MACHINES = pod_1x1_2X2Y
BSG_SIM_BASE = simsc
else ifeq ($(BSG_PLATFORM),xcelium)
DEFAULT_MACHINES = pod_1x1 pod_1x1_hbm2 pod_4x4 pod_4x4_hbm2
BSG_SIM_BASE = simx
endif

