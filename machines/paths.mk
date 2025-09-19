
########################################
# Environment
SHELL:=/bin/bash

# By convention, basejump_stl and bsg_cadenv are the same directory as $(BSG_MANYCORE_DIR)
BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)
BSG_CADENV_DIR ?= $(abspath $(BSG_MANYCORE_DIR)/../bsg_cadenv)
BASEJUMP_STL_DIR ?= $(abspath $(BSG_MANYCORE_DIR)/../basejump_stl)
RISCV_INSTALL_DIR ?= $(abspath $(BSG_MANYCORE_DIR)/software/riscv-tools/riscv-install)
LLVM_DIR ?= $(RISCV_INSTALL_DIR)

########################################
# Other tools

DEV8_GCC ?= /opt/rh/devtoolset-8/root/usr/bin/gcc
DEV8_GXX ?= /opt/rh/devtoolset-8/root/usr/bin/g++

GCCVERSION := $(shell gcc -dumpversion)
GCC_VERILATOR_COMPAT := $(filter $(shell echo $(GCCVERSION) | cut -f1 -d.),8 9 10 11 12 13)
GCC_LLVM_COMPAT := $(filter $(shell echo $(GCCVERSION) | cut -f1 -d.),8 9 10 11)

# Can override to python2/3 if needed
SURELOG ?= surelog
VERILATOR ?= verilator
PYTHON ?= $(if $(shell which python3),python3,python)
GCC ?= $(if $(GCC_LLVM_COMPAT),gcc,$(DEV8_GCC))
GXX ?= $(if $(GCC_LLVM_COMPAT),g++,$(DEV8_GXX))
# We need cmake3. On older RHEL systems, cmake is version 2 and cmake3
# is version 3. On newer systems cmake is version3. Default to cmake3
# if it is available, and backup to cmake. If cmake is NOT version 3,
# it will fail during LLVM compilation with the appropriate warning.
CMAKE ?= $(if $(shell which cmake3),cmake3,cmake)
# Build tool: Pick ninja over make if available
GENERATOR ?= $(if $(shell which ninja),Ninja,Unix Makefiles)

########################################
# Useful variables, exported for script usage

export RISCV_BIN_DIR = $(RISCV_INSTALL_DIR)/bin
export RISCV_LIB_DIR = $(RISCV_INSTALL_DIR)/lib
export LLVM_BIN_DIR = $(LLVM_DIR)/bin
export RISCV = $(RISCV_INSTALL_DIR)

########################################
# CAD Setup

ifneq ($(wildcard $(BSG_CADENV_DIR)/cadenv.mk),)
$(info CAD Environment: using $(BSG_CADENV_DIR)/cadenv.mk to configure cad tools)
include $(BSG_CADENV_DIR)/cadenv.mk
else
$(info CAD Environment: not found at $(BSG_CADENV_DIR)/cadenv.mk, ignoring...)
endif

########################################
# CAD Validation

ifndef VCS
$(warning Unfamiliar machine/cadtool setup:)
$(warning Please define the $$VCS which points to the VCS binaries)
$(warning Probably also need VCS_HOME, SNPSLMD_LICENSE_FILE, maybe LM_LICENSE_FILE)
endif

ifndef DVE
$(warning Unfamiliar machine/cadtool setup:)
$(warning Please define the $$DVE which points to the DVE binaries)
$(warning Probably also need VCS_HOME, SNPSLMD_LICENSE_FILE, maybe LM_LICENSE_FILE)
endif

ifndef XRUN
$(warning Unfamiliar machine/cadtool setup:)
$(warning Please define the $$XRUN which points to the XRUN binaries)
$(warning Probably also need XRUN_HOME, SNPSLMD_LICENSE_FILE, maybe LM_LICENSE_FILE)
endif

ifndef IGNORE_CADENV
$(info CAD Environment: using $(BSG_CADENV_DIR)/cadenv.mk to configure cad tools)
include $(BSG_CADENV_DIR)/cadenv.mk
endif

ifeq ($(wildcard $(BASEJUMP_STL_DIR)/imports/DRAMSim3/Makefile),)
$(error DRAMSim3 has not been submoduled in basejump_stl, see top-level README.md)
endif

ifeq (,$(GCC_VERILATOR_COMPAT))
$(warning Verilator requires 7 < GCC version < 14)
endif

ifeq (,$(GCC_LLVM_COMPAT))
$(warning LLVM requires 7 < GCC version < 12)
endif

