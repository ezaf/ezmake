# Base Makefile for EzMake
#
# Copyright (c) 2018 Kirk Lange <github.com/kirklange>
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



# Root directory
# Should be set by "includer" Makefile
#ROOT = ../

# Binaries
BIN_DIR = $(ROOT)/bin
# Build
BLD_DIR = $(ROOT)/build
# Data (config, textures, etc)
DAT_DIR = $(ROOT)/data
# Documentation
DOC_DIR = $(ROOT)/docs
# External (git submodule) directory
# Should be set by "includer" Makefile
#SUB_DIR = $(ROOT)/sub
# Include
INC_DIR = $(ROOT)/include
# Libraries
LIB_DIR = $(ROOT)/lib
# Projects, examples, and tests
PRJ_DIR = $(ROOT)/src
# Source
SRC_DIR = $(ROOT)/src
# Tests
TST_DIR = $(ROOT)/test



# Add source directory and file extensions to source file names.
SHARED_OBJS = \
	$(foreach OBJ,$(SUB_SRC_FILES),$(SUB_DIR)/$(OBJ)) \
	$(foreach EXT,$(SRC_EXTS), \
		$(foreach DIR,$(SUB_SRC_DIRS), \
				$(wildcard $(SUB_DIR)/$(DIR)/*.$(EXT))) \
		$(foreach DIR,$(LIB_SUBDIR), \
				$(wildcard $(SRC_DIR)/$(DIR)/*.$(EXT))) )

MAIN_OBJS = \
	$(foreach EXT,$(SRC_EXTS), \
		$(foreach DIR,$(MAIN_SUBDIRS), \
				$(wildcard $(PRJ_DIR)/$(DIR)/*.$(EXT))) )

# Include and library flags
INC = -I$(INC_DIR) $(foreach DIR,$(EXT_INC_DIRS),-I$(SUB_DIR)/$(DIR)) \
	  $(foreach DIR,$(PREFIXES),-I$(DIR)/include)
LIB = $(foreach DIR,$(PREFIXES),-L$(DIR)/lib)

# Package flags
ifneq ($(PKGS),)
	PCF = `pkg-config --cflags --silence-errors $(PKGS)`
	PLF = `pkg-config --libs --silence-errors $(PKGS)`
endif

# Find what OS we're on so we can better configure all the compiler options.
# All compiler flags can be customized on a per-platform basis.
# Linux->"Linux" | MacOS->"Darwin" | Windows->"*_NT-*"
ifneq (, $(shell uname -s | grep -E _NT))
	CULT = windows
	DYN_EXT = dll
	# Uncomment to remove console window
	CF += #-Wl,-subsystem,windows
	# -lmingw32 must come before everything else
	LF_TEMP := $(LF)
	LF = -lmingw32 $(LF_TEMP)
	OPEN = cmd //c start "${@//&/^&}"
endif
ifneq (, $(shell uname -s | grep -E Linux))
	CULT = linux
	DYN_EXT = so
	CF +=
	LF +=
	OPEN = xdg-open
endif
ifneq (, $(shell uname -s | grep -E Darwin))
	CULT = macos
	DYN_EXT = dylib
	# TODO: test on MacOS
endif

# Figure out compile and run targets based on compiler
# TODO: When adding multiple-projects compiling, change COMPILE's RUNs
ifeq ($(CC), emcc)
	CF = -O3
	LF =
	ifneq (, $(findstring sdl2, $(PKGS)))
		LF += -s USE_SDL=2
	endif
	ifneq (, $(findstring SDL_image, $(PKGS)))
		LF += -s USE_SDL_IMAGE=2
	endif
	ifneq (, $(findstring SDL_ttf, $(PKGS)))
		LF += -s USE_SDL_TTF=2
	endif
	ifneq (, $(findstring SDL_net, $(PKGS)))
		LF += -s USE_SDL_NET=2
	endif

	COMPILE = \
		$(foreach MAIN,$(MAIN_SUBDIRS), \
			$(CC) $(SHARED_OBJS) \
			$(foreach EXT,$(SRC_EXTS), \
					$(wildcard $(PRJ_DIR)/$(MAIN)/*.$(EXT)) ) \
			-I$(PRJ_DIR)/$(MAIN) $(INC) $(CF) $(LF) \
			-o $(BLD_DIR)/$(MAIN)/$(MAIN).html && \
		)$(NULL)

	RUN_CALL = $(OPEN) $(BLD_DIR)/$(RUN)/$(RUN).html
else

	COMPILE = \
		$(foreach MAIN,$(MAIN_SUBDIRS), \
				mkdir -p $(BLD_DIR)/$(MAIN) && \
				cp -R $(DAT_DIR) $(BLD_DIR)/$(MAIN)/ && ) \
		$(CC) $(SHARED_OBJS) $(INC) $(LIB) $(PCF) $(CF) $(LF)

	ifeq ($(MODE), dynamic)
		LIB_OUT = $(BIN_DIR)/$(LIB_NAME).$(DYN_EXT)

		COMPILE += -shared -fPIC -o $(LIB_OUT) $(PLF) && \
			$(foreach MAIN,$(MAIN_SUBDIRS), \
					cp -R $(LIB_OUT) $(BLD_DIR)/$(MAIN)/ && ) \
			$(foreach MAIN,$(MAIN_SUBDIRS), \
				$(CC) \
				$(foreach EXT,$(SRC_EXTS), \
						$(wildcard $(PRJ_DIR)/$(MAIN)/*.$(EXT))) \
				-I$(PRJ_DIR)/$(MAIN) \
				$(INC) $(LIB) $(PCF) $(CF) $(LF) $(LIB_OUT) \
				-o $(BLD_DIR)/$(MAIN)/$(MAIN) $(PLF) && \
			)$(NULL)
	else
		COMPILE += -c $(PLF) && \
			ar rcs $(LIB_DIR)/lib$(LIB_NAME).a *.o && \
			rm *.o && \
			$(foreach MAIN,$(MAIN_SUBDIRS), \
				$(CC) \
				$(foreach EXT,$(SRC_EXTS), \
					$(wildcard $(PRJ_DIR)/$(MAIN)/*.$(EXT))) \
				-I$(PRJ_DIR)/$(MAIN) \
				$(INC) $(LIB) -L$(LIB_DIR) -l$(LIB_NAME) $(PCF) $(CF) $(LF) \
				-o $(BLD_DIR)/$(MAIN)/$(MAIN) $(PLF) && \
			)$(NULL)
	endif

	RUN_CALL = $(BLD_DIR)/$(RUN)/$(RUN)
	TST_CALL = $(foreach T,$(TEST), \
				   $(foreach INPUT, \
						$(if $(wildcard $(TST_DIR)/$(T)/*), \
							$(wildcard $(TST_DIR)/$(T)/*), \
							/dev/null), \
						echo && \
						echo "== $(T) < $(notdir $(INPUT)) ==" && \
						$(BLD_DIR)/$(T)/$(T) < $(INPUT) && \
						echo &&\
					))$(NULL)
endif



# TODO: version check python and doxygen
#ifeq(, $(shell where python3))
#endif

PYV_FULL = $(wordlist 2,4,$(subst ., ,$(shell python3 --version 2>&1)))
PYV_MAJOR = $(word 1,${PYV_FULL})
PYV_MINOR = $(word 2,${PYV_FULL})
PYV_PATCH = $(word 3,${PYV_FULL})

PERCENT := %
MAKE = make --no-print-directory
NULL = echo >/dev/null



.PHONY: help all open $(DOC_DIR) $(SUB_DIR) $(BLD_DIR) rtd run test clean

help :
	@printf "\nTODO: describe make targets\n"

all :
	$(MAKE) $(DOC_DIR)
	$(MAKE) compile
	$(MAKE) run

$(DOC_DIR) :
	mkdir -p $(DOC_DIR)
	rm -rf $(DOC_DIR)/*
	$(MAKE) $(SUB_DIR)
	@# TODO: version check, m.css requires python 3.6+ and doxygen 1.8.14+
	python $(SUB_DIR)/m.css/doxygen/dox2html5.py .doxyfile
	cp $(SUB_DIR)/m.css/css/m-dark+doxygen.compiled.css \
		$(DOC_DIR)/m-dark+doxygen.compiled.css
	find docs/m-dark+doxygen.compiled.css -type f -exec \
		sed -i 's/text-indent: 1\.5rem/text-indent: 0rem/g' {} \;	
	cd $(DOC_DIR) && rm -rf xml/
	@# To be honest the default latex/pdf style is pretty ugly.
	@# TODO: make latex/pdf output look more like sphinx/readthedocs
	@#cd $(DOC_DIR)/latex/ && make && mv refman.pdf ../refman.pdf && \
		cd ../ && rm -rf latex/
	cd $(DOC_DIR) && rm -rf latex/

rtd :
	$(OPEN) docs/index.html
	@#$(OPEN) docs/refman.pdf

$(SUB_DIR) :
	git submodule init
	git submodule update

$(BLD_DIR) :
	mkdir -p $(BLD_DIR)
	mkdir -p $(DAT_DIR)
	$(MAKE) compile

compile : $(SHARED_OBJS) $(MAIN_OBJS)
	mkdir -p $(BIN_DIR)
	mkdir -p $(LIB_DIR)
	$(COMPILE)

run :
	@echo
	$(RUN_CALL)
	@echo

test :
	@printf "== BEGIN TESTING ==\n"
	@$(TST_CALL)
	@printf "\n== END TESTING ==\n"



CLEAN = $(BLD_DIR) $(DOC_DIR) $(SUB_DIR)
CLEAN_COMMAND = $(foreach DIR,$(CLEAN),rm -rf $(DIR)/* && )$(NULL)

clean :
	$(CLEAN_COMMAND)



# File/Module name and location
F = ExampleAPI/example
# Test input file name
T =
# Source file extension - C Module
C = c
# Header file extension - C Module
H = h
# Source file extension - C++ Object
CPP = cpp
# Header file extension - C++ Object
HPP = hpp
# Get license command
LICENSE = `cat $(ROOT)/LICENSE | sed -e $$'s/\r//' | awk '{print " *  " $$0}'`

open : # Usage example: `make open F=ezhello`
	vim -O `find $(SRC_DIR) -name $(F).*` `find $(INC_DIR) -name $(F).*`

module : # Usage example: `make module F=ezhello`
	mkdir -p $(INC_DIR)/$(LIB_SUBDIR)/`dirname $(F)`
	mkdir -p $(SRC_DIR)/$(LIB_SUBDIR)/`dirname $(F)`
	@printf "\
	/** $(F).$(H)\n\
	 *  \n\
	$(LICENSE)\n\
	 */\n\
	\n\
	#ifndef `basename $(F) | awk '{print toupper($$0)}'`_H\n\
	#define `basename $(F) | awk '{print toupper($$0)}'`_H\n\
	\n\
	/** @file       $(F).$(H)\n\
	 *  @brief      Lorem ipsum\n\
	 *  @details    Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n\
	 */\n\
	\n\
	#ifdef __cplusplus\n\
	extern "C"\n\
	{\n\
	#endif\n\
	\n\
	#include <stdint.h>\n\
	\n\
	\n\
	\n\
	/** @brief      Lorem ipsum\n\
	 *  @details    Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do\n\
	 *              eiusmod tempor incididunt ut labore et dolore magna aliqua.\n\
	 *  @param      alpha   Ut enim ad minim veniam, quis nostrud exercitation\n\
	 *                      ullamco laboris nisi ut aliquip ex ea commodo\n\
	 *                      consequat.\n\
	 *  @param      beta    Duis aute irure dolor in reprehenderit in voluptate\n\
	 *                      velit esse cillum dolore eu fugiat nulla pariatur.\n\
	 *  @return     Excepteur sint occaecat cupidatat non proident, sunt in culpa\n\
	 *              qui officia deserunt mollit anim id est laborum.\n\
	 */\n\
	int16_t `basename $(F) | awk '{print tolower($$0)}'`_example(int16_t alpha, int16_t beta);\n\
	\n\
	\n\
	\n\
	#ifdef __cplusplus\n\
	}\n\
	#endif\n\
	\n\
	#endif /* `basename $(F) | awk '{print toupper($$0)}'`_H */\
	" >> $(INC_DIR)/$(LIB_SUBDIR)/$(F).$(H)
	@printf "\
	/*  $(F).$(C)\n\
	 *  \n\
	$(LICENSE)\n\
	 */\n\
	\n\
	#include \"$(LIB_SUBDIR)/$(F).$(H)\"\n\
	\n\
	\n\
	\n\
	int16_t `basename $(F) | awk '{print tolower($$0)}'`_example(int16_t alpha, int16_t beta)\n\
	{\n\
	    return alpha + beta;\n\
	}\
	" >> $(SRC_DIR)/$(LIB_SUBDIR)/$(F).$(C)
	vim -O $(SRC_DIR)/$(LIB_SUBDIR)/$(F).$(C) $(INC_DIR)/$(LIB_SUBDIR)/$(F).$(H)

main : # Usage example: `make main F=test_hello T=say_hello`
	mkdir -p $(SRC_DIR)/$(F)
	if [ $(T) ]; then mkdir -p $(TST_DIR)/$(F); fi
	@printf "\
	/*  $(F).$(C)\n\
	 *  \n\
	$(LICENSE)\n\
	 */\n\
	\n\
	/** @file       $(F).$(C)\n\
	 *  @brief      Lorem ipsum\n\
	 *  @details    Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n\
	 */\n\
	\n\
	#include <stdio.h>\n\
	\n\
	\n\
	\n\
	int main(int argc, char *argv[])\n\
	{\n\
	    printf(\"Hello world! This is \'$(F)\'.\\\n\");\n\
	    return 0;\n\
	}\
	" >> $(SRC_DIR)/$(F)/$(F).$(C)
	vim -O $(SRC_DIR)/$(F)/$(F).$(C) `if [ $(T) ]; then printf $(TST_DIR)/$(F)/$(T); fi`
