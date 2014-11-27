# The TARGET variable determines what target system the application is
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling
TARGET = SLICEKIT-A16

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to
# the project name
APP_NAME = EtherXTag

# The USED_MODULES variable lists other module used by the application.
USED_MODULES = module_ethernet module_ethernet_board_support module_xtcp module_zeroconf sc_jtag/module_jtag_master sc_jtag/module_jtag_otp_access sc_jtag/module_xcore_debug sc_jtag/module_xs1_su_debug

# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
# XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to
# xcc for the final link (mapping) stage.
XCC_FLAGS_Debug = -O0 -g -fxscope
XCC_FLAGS_Release = -O2 -g
XCC_FLAGS_uip_server_support.c = $(XCC_FLAGS) -O0
XCC_FLAGS_dbg_manager.xc = $(XCC_FLAGS) -O0

# The XCORE_ARM_PROJECT variable, if set to 1, configures this
# project to create both xCORE and ARM binaries.
XCORE_ARM_PROJECT = 0

# The VERBOSE variable, if set to 1, enables verbose output from the make system.
VERBOSE = 1

XMOS_MAKE_PATH ?= ../..
-include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common