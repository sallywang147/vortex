ROOT_DIR := $(realpath ../../..)
include $(ROOT_DIR)/config.mk

PROJECT := attack_2_listen

SRC_DIR := $(VORTEX_HOME)/tests/opencl/$(PROJECT)

SRCS := $(SRC_DIR)/covertCLListener.cc

covertCLListener.cl: $(SRC_DIR)/covertCLListener.cl
	cp $< $@
	
KERNEL_SRCS := covertCLListener.cl 

OPTS ?= -n64
include ../common.mk