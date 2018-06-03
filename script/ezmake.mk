# Base Makefile for EzMake
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



# Root directory
# Should be set by "includer" Makefile
#ROOT = ../

# Binaries
BIN_DIR = $(ROOT)/bin
# Build
BLD_DIR = $(ROOT)/build
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
# Resources (config, textures, etc)
RES_DIR = $(ROOT)/res
# Source
SRC_DIR = $(ROOT)/src



# Add source directory and file extensions to source file names.
SHARED_OBJS = \
		$(foreach OBJ,$(SUB_SRC_FILES),$(SUB_DIR)/$(OBJ)) \
	    $(foreach EXT,$(SRC_EXTS), \
	    $(foreach DIR,$(SUB_SRC_DIRS),$(wildcard $(SUB_DIR)/$(DIR)/*.$(EXT))) \
	    $(foreach DIR,$(SRC_SUBDIRS),$(wildcard $(SRC_DIR)/$(DIR)/*.$(EXT))) )

MAIN_OBJS = \
	   $(foreach EXT,$(SRC_EXTS), \
	   $(foreach DIR,$(MAIN_SUBDIRS),$(wildcard $(PRJ_DIR)/$(DIR)/*.$(EXT))) )

# Include and library flags
INC = -I$(INC_DIR) $(foreach DIR,$(EXT_INC_DIRS),-I$(SUB_DIR)/$(DIR)) \
	  $(foreach DIR,$(PREFIXES),-I$(DIR)/include) \
	  -I$(PRJ_DIR)/$(MAIN_SUBDIR)
LIB = $(foreach DIR,$(PREFIXES),-L$(DIR)/lib)

# Package flags
ifneq ($(PKGS),)
	PF = `pkg-config --cflags --libs --silence-errors $(PKGS)`
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
# TODO: When adding multiple-projects compiling, change COMPILE's EXEC_MEs
ifeq ($(CC), emcc)
	COMPILE = $(CC) $(SHARED_OBJS) $(MAIN_OBJS) $(INC) $(CF) $(LF) \
			  -o $(BLD_DIR)/$(EXEC_ME)/$(EXEC_ME).html
	RUN = $(OPEN) $(BLD_DIR)/$(EXEC_ME)/$(EXEC_ME).html
else
	COMPILE = mkdir -p $(BLD_DIR)/$(EXEC_ME)
	ifeq ($(MODE), dynamic)
		TEMP := $(BIN_DIR)/$(LIB_NAME).$(DYN_EXT)
		COMPILE += && \
			$(CC) $(SHARED_OBJS) $(INC) $(LIB) $(PF) $(CF) $(LF) \
				-shared -fPIC -o $(TEMP) && \
			cp -R $(TEMP) $(BLD_DIR)/$(EXEC_ME)/ && \
	        $(CC) $(MAIN_OBJS) $(INC) $(LIB) $(PF) $(CF) $(LF) \
				$(TEMP) -o $(BLD_DIR)/$(EXEC_ME)/$(EXEC_ME)
	else
		COMPILE += && \
			$(CC) $(SHARED_OBJS) $(INC) $(LIB) $(PF) $(CF) $(LF) \
				-c && \
			ar rcs $(LIB_DIR)/lib$(LIB_NAME).a *.o && \
			rm *.o && \
	        $(CC) $(MAIN_OBJS) $(INC) $(LIB) -L$(LIB_DIR) -l$(LIB_NAME) \
				$(PF) $(CF) $(LF) -o $(BLD_DIR)/$(EXEC_ME)/$(EXEC_ME)
	endif
	RUN = $(BLD_DIR)/$(EXEC_ME)/$(EXEC_ME)
endif



# TODO: version check python and doxygen
#ifeq(, $(shell where python3))
#endif

PYV_FULL = $(wordlist 2,4,$(subst ., ,$(shell python3 --version 2>&1)))
PYV_MAJOR = $(word 1,${PYV_FULL})
PYV_MINOR = $(word 2,${PYV_FULL})
PYV_PATCH = $(word 3,${PYV_FULL})

MAKE = make --no-print-directory



.PHONY : all $(BLD_DIR) run dirs deps $(SUB_DIR) $(DOC_DIR) rtd compile help
.PHONY : open clean clean-$(BLD_DIR) clean-$(DOC_DIR) clean-$(SUB_DIR)

all :
	$(MAKE) $(DOC_DIR)
	$(MAKE) compile
	$(MAKE) run

help :
	@echo
	@echo "TODO: describe make targets"
	@echo

open : # Usage example: `make open F=hello W=vs`
	@$(SUB_DIR)/ezc/script/ezmake_open.sh \
		$(SRC_DIR) $(INC_DIR) $(F) $(W)

$(DOC_DIR) :
	mkdir -p $(DOC_DIR)
	$(MAKE) clean-$(DOC_DIR)
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

# TODO: Change this EXEC_ME later
$(BLD_DIR) :
	mkdir -p $(BLD_DIR)
	mkdir -p $(RES_DIR)
	cp -R $(RES_DIR) $(BLD_DIR)/$(EXEC_ME)/
	$(MAKE) compile

compile : $(SHARED_OBJS) $(MAIN_OBJS)
	mkdir -p $(BIN_DIR)
	mkdir -p $(LIB_DIR)
	$(COMPILE)

run :
	@echo
	$(RUN) $(ADD)
	@echo

clean :
	$(MAKE) clean-build

clean-all :
	$(MAKE) clean-build
	$(MAKE) clean-doc
	$(MAKE) clean-sub

clean-build :
	rm -rf $(BLD_DIR)/*

clean-doc :
	rm -rf $(DOC_DIR)/*

clean-sub :
	rm -rf $(SUB_DIR)/*

