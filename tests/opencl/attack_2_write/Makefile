ROOT_DIR := $(realpath ../../..)
include $(ROOT_DIR)/config.mk

PROJECT := attack_2_write

SRC_DIR := $(VORTEX_HOME)/tests/opencl/$(PROJECT)

SRCS := $(SRC_DIR)/covertCLWriter.cc

covertCLWriter.cl: $(SRC_DIR)/covertCLWriter.cl
	cp $< $@
	
KERNEL_SRCS := covertCLWriter.cl 

OPTS ?= -n64
include ../common.mk