
BSG_PLATFORM ?= vcs

ifeq ($(BSG_PLATFORM),vcs)
DEFAULT_MACHINES = pod_1x1 pod_1x1_hbm2 pod_4x4
BSG_SIM_BASE = simv
else ifeq ($(BSG_PLATFORM),verilator)
DEFAULT_MACHINES = pod_1x1_4X2Y
BSG_SIM_BASE = simsc
endif

