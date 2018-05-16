# Configuration Makefile for EzC projects
#
# Copyright (c) 2018 Kirk Lange
#
# This software is provided 'as-is', without any express or implied
# warranty. In no event will the authors be held liable for any damages
# arising from the use of this software.
#
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
#
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.



###############################################################################
##############################  Standard Options  #############################
###############################################################################

# Directory within src/ of the project or test that you want to build
MAIN_SUBDIR = demo

# Directory within src/ for which all *.c files will be added to the build.
# The difference between this and `MAIN_SUBDIR` is that this is intended to
#   indicate where the API source files are located.
SRC_SUBDIRS = hello

# Needed submodule include directories within ext/
SUB_INC_DIRS =

# Needed submodule source directories within ext/
SUB_SRC_DIRS =

# If the submodule has its test source files in the same directory as its
#   actual API source files (facepalm), then you may want to manually specify
#   individual source files here
SUB_SRC_FILES =

# Name for the build subdirectory and executable (file extension not necessary)
OUT = $(MAIN_SUBDIR)



###############################################################################
##############################  Advanced Options  #############################
###############################################################################

# Compiler and linker settings
# In many cases the order in which your `-l`s appear matters!
CC = gcc
CF = -std=c89 -pedantic -O3 -w
LF =

# OFTEN NECESSARY FOR WINDOWS!!!
# Outside include and lib directories for `gcc` such as the paths to the SDL2
# Change the path to match where you have installed the stuff on your machine
# Commented out are examples for luac
GCC_I_DIRS_WIN = #D:/org/lua/src
GCC_L_DIRS_WIN = #D:/org/lua/src

# Needed for Linux if you installed your libraries in your home directory
GCC_I_DIRS_LIN = #$$HOME/include
GCC_L_DIRS_LIN = #$$HOME/lib

# Root directory
ROOT = .

# Submodule directory
SUB_DIR = $(ROOT)/sub



###############################################################################
##########################  Initialize EzC Framework  #########################
###############################################################################

.PHONY : init

init :
	@rm -rf $(SUB_DIR)/ezc
	@rm -rf $(SUB_DIR)/m.css
	@rm -rf .git/modules/$(SUB_DIR)/ezc
	@rm -rf .git/modules/$(SUB_DIR)/m.css
	@git rm -r --cached --ignore-unmatch $(SUB_DIR)
	git submodule add -f https://github.com/ezaf/ezc.git $(SUB_DIR)/ezc
	git submodule add -f https://github.com/mosra/m.css.git $(SUB_DIR)/m.css
	@rm -f script/ezc.mk
	@rm -f script/ezc_open.sh
	@mkdir -p script
	@rmdir --ignore-fail-on-non-empty script

-include $(SUB_DIR)/ezc/script/ezc.mk
