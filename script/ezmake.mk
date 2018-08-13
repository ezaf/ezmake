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
BIN_DIR = bin
# Data (config, textures, etc)
DAT_DIR = data
# Documentation
DOC_DIR = docs
# Emscripten Builds
EMC_DIR = $(BIN_DIR)
# Copied header files
INC_DIR = include
# Libraries
LIB_DIR = lib
# Source
SRC_DIR = src
# External (git submodule) directory
# Should be set by "includer" Makefile
#SUB_DIR = sub
# Tests
TST_DIR = test

# Source subdirecties
SRC_SUBDIRS_MAIN = $(foreach DIR,$(MAINS),$(SRC_DIR)/$(DIR))
SRC_SUBDIRS_MODULE = $(foreach DIR,$(MODULES),$(SRC_DIR)/$(DIR))
SRC_SUBDIRS_ALL = $(SRC_SUBDIRS_MAIN) $(SRC_SUBDIRS_MODULE) \
			  $(foreach DIR,$(SUB_SUBDIRS),$(SUB_DIR)/$(DIR))

# Include and library flags
CF = -fPIC -I$(ROOT)/$(SRC_DIR) \
	 $(foreach DIR,$(SUB_SUBDIRS),-I$(ROOT)/$(SUB_DIR)/$(DIR)) \
	 $(foreach DIR,$(PREFIXES),-I$(DIR)/include)
LF += $(foreach DIR,$(PREFIXES),-L$(DIR)/lib)

# Package flags
ifneq ($(PKGS),)
	CF += `pkg-config --cflags --silence-errors $(PKGS)`
	LF += `pkg-config --libs --silence-errors $(PKGS)`
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
	# TODO: determine OPEN on MacOS
endif

# Figure out compile and run targets based on compiler
# TODO: When adding multiple-projects compiling, change COMPILE's RUNs
ifeq ($(CC), emcc)
	CF += --preload-file $(ROOT)/$(DAT_DIR)
	ifneq (,$(findstring sdl2, $(PKGS)))
		LF += -s USE_SDL=2
	endif
	ifneq (,$(findstring SDL_image, $(PKGS)))
		LF += -s USE_SDL_IMAGE=2
	endif
	ifneq (,$(findstring SDL_ttf, $(PKGS)))
		LF += -s USE_SDL_TTF=2
	endif
	ifneq (,$(findstring SDL_net, $(PKGS)))
		LF += -s USE_SDL_NET=2
	endif

	COMPILE = \
		$(foreach DIR,$(SRC_SUBDIRS_MAIN), \
			$(CC) $(CF) -I$(ROOT)/$(SRC_DIR)/$(DIR) \
			$(foreach EXT,$(SRC_EXTS), \
				$(wildcard $(ROOT)/$(SRC_DIR)/$(DIR)/*.$(EXT)) ) \
			$(LF) -o $(ROOT)/$(EMC_DIR)/$(MAIN).html && ) $(NULL)

	RUN_CALL = $(OPEN) $(ROOT)/$(EMC_DIR)/$(RUN).html
endif

MAKE = make --no-print-directory
NULL = echo >/dev/null
# Credit: https://stackoverflow.com/a/786530/5890633
REVERSE = $(if $(1),$(call REVERSE,$(wordlist 2,$(words $(1)),$(1)))) \
		  $(firstword $(1))



help :
	@echo "TODO: Write help documentation."

$(MODULES) $(MAINS) : FORCE
	@# Nothing needed here.

%.o : %.c
	$(CC) $(CF) -c $< -o $@

%.o : %.cc
	$(CC) $(CF) -c $< -o $@

%.o : %.cxx
	$(CC) $(CF) -c $< -o $@

%.o : %.cpp
	$(CC) $(CF) -c $< -o $@

%.o : %.c++
	$(CC) $(CF) -c $< -o $@

$(BIN_DIR) $(DAT_DIR) $(INC_DIR) $(LIB_DIR) $(SRC_DIR) :
	mkdir -p $(ROOT)/$@

$(DOC_DIR) : FORCE
	mkdir -p $(ROOT)/$(DOC_DIR)
	rm -rf $(ROOT)/$(DOC_DIR)/*
	@$(MAKE) $(SUB_DIR)
	doxygen >/dev/null

$(SUB_DIR) : FORCE
	mkdir -p $(ROOT)/$@
	git submodule update --init --remote --force

$(BIN_DIR)/%.$(DYN_EXT) : % $(BIN_DIR)
	@if [ $$($(MAKE) $(SRC_DIR)/$<) = *"is up to date."* ] && \
		[ -f $(ROOT)/$@ ]; then \
		echo "make[$(MAKELEVEL)]: '$(ROOT)/$@' is up to date."; \
	else \
		echo "$(CC) $(CF) -shared \
$$(find $(ROOT)/$(SRC_DIR)/$< -name "*.o") -L$(ROOT)/$(LIB_DIR) \
$$(find $(ROOT)/$(BIN_DIR) -name "*.$(DYN_EXT)") \
-o $(ROOT)/$@"; \
		$(CC) $(CF) -shared \
			$$(find $(ROOT)/$(SRC_DIR)/$< -name "*.o") -L$(ROOT)/$(LIB_DIR) \
			$$(find $(ROOT)/$(BIN_DIR) -name "*.$(DYN_EXT)") \
			-o $(ROOT)/$@; \
	fi

$(INC_DIR)/% : % $(INC_DIR)
	@mkdir -p $@
	@$(foreach EXT,$(INC_EXTS), \
		$(foreach FILE,$(wildcard $(ROOT)/$(SRC_DIR)/$</*.$(EXT)), \
			if [ $$(diff -N $(FILE) \
					$(patsubst ./$(SRC_DIR)%,./$(INC_DIR)%,$(FILE))) ]; then \
				echo "cp $(FILE) \
$(patsubst ./$(SRC_DIR)%,./$(INC_DIR)%,$(FILE))"; \
				cp $(FILE) $(patsubst ./$(SRC_DIR)%,./$(INC_DIR)%,$(FILE)); \
			fi))

$(LIB_DIR)/lib%.a : % $(LIB_DIR)
	@if [ $$($(MAKE) $(SRC_DIR)/$<) = *"is up to date."* ] && \
		[ -f $(ROOT)/$@ ]; then \
		echo "make[$(MAKELEVEL)]: '$(ROOT)/$@' is up to date."; \
	else \
		echo "ar rcs $@ $$(find $(ROOT)/$(SRC_DIR)/$< -name "*.o")"; \
		ar rcs $@ $$(find $(ROOT)/$(SRC_DIR)/$< -name "*.o"); \
	fi

$(SRC_SUBDIRS_ALL) : FORCE
	@$(foreach EXT,$(SRC_EXTS), \
		$(foreach FILE,$(wildcard $@/*.$(EXT)), \
			$(MAKE) $(patsubst %.$(EXT),%.o,$(FILE))))

mode-main = \
	uptodate=0; modules=0; \
	output=$$($(MAKE) $(BIN_DIR)); \
	echo "$$output"; \
	if [ $$output = *"is up to date." ]; then \
		let "uptodate+=1"; fi; \
	output=$$($(MAKE) $(SRC_DIR)/$(2)); \
	echo "$$output"; \
	if [ $$output = *"is up to date." ]; then \
		let "uptodate+=1"; fi; \
	for MOD in $(MODULES); do \
		let "modules+=1"; \
		output=$$($(MAKE) $(1)-$$MOD); \
		echo "$$output"; \
		if [ $$output = *"is up to date." ]; then \
			let "uptodate+=1"; fi; \
	done; \
	let "uptodate-=2"; \
	if [ uptodate -eq modules ] && \
		[ -x $(ROOT)/$(BIN_DIR)/$(1)-$(2) ]; then \
		echo "make[$(MAKELEVEL)]: '$(ROOT)/$(BIN_DIR)/$(1)-$(2)' \
is up to date."; \
	else \
		if [ static == $(1) ]; then \
			dir=$(LIB_DIR); \
			pre=lib; \
			ext=a; fi; \
		if [ dynamic == $(1) ]; then \
			dir=$(BIN_DIR); \
			pre=; \
			ext=$(DYN_EXT); fi; \
		echo "$(CC) $(CF) \
$$(find $(ROOT)/$(SRC_DIR)/$(2) -type f -name "*.o") \
$(foreach MOD,$(call REVERSE,$(MODULES)), \
$(ROOT)/$$dir/$$pre\$(MOD).$$ext) \
-o $(ROOT)/$(BIN_DIR)/$(1)-$<"; \
		$(CC) $(CF) $$(find $(ROOT)/$(SRC_DIR)/$(2) -type f -name "*.o") \
			$(foreach MOD,$(call REVERSE,$(MODULES)), \
				$(ROOT)/$$dir/$$pre\$(MOD).$$ext) \
			-o $(ROOT)/$(BIN_DIR)/$(1)-$<; \
	fi

# Where % is one of MODULES or MAINS
static-% : %
	@$(if $(findstring $<,$(MODULES)), \
		$(MAKE) $(LIB_DIR)/lib$<.a && \
		$(MAKE) $(INC_DIR)/$<)
	@$(if $(findstring $<,$(MAINS)),$(call mode-main,static,$<))

# Where % is one of MODULES or MAINS
dynamic-% : %
	@$(if $(findstring $<,$(MODULES)), \
		$(MAKE) $(BIN_DIR)/$<.$(DYN_EXT) && \
		$(MAKE) $(INC_DIR)/$<)
	@$(if $(findstring $<,$(MAINS)),$(call mode-main,dynamic,$<))

static-all : FORCE
	@$(foreach MAIN,$(MAINS), \
		echo "make static-$(MAIN)" && \
		$(MAKE) static-$(MAIN) && ) $(NULL)

dynamic-all : FORCE
	@$(foreach MAIN,$(MAINS), \
		echo "make dynamic-$(MAIN)" && \
		$(MAKE) dynamic-$(MAIN) && ) $(NULL)

all : FORCE
	@$(MAKE) static-all
	@$(MAKE) dynamic-all
	@$(MAKE) $(DOC_DIR)

DATCPY = cp -r -u $(ROOT)/$(DAT_DIR) $(ROOT)/$(BIN_DIR)

test : FORCE
	@$(MAKE) $(BIN_DIR)
	$(DATCPY)
	@echo "== BEGIN TESTING =="
	@$(foreach SD,static dynamic, \
		$(foreach T,$(TEST), \
		   $(foreach INPUT, \
					$(if $(wildcard $(ROOT)/$(TST_DIR)/$(T)/*), \
						$(wildcard $(ROOT)/$(TST_DIR)/$(T)/*), \
						/dev/null), \
				echo && \
				echo "== $(SD)-$(T) < $(notdir $(INPUT)) ==" && \
				$(ROOT)/$(BIN_DIR)/$(SD)-$(T) < $(INPUT) && \
			))) echo
	@echo "== END TESTING =="

RUNEXESTA = $(ROOT)/$(BIN_DIR)/static-$(RUN)
RUNEXEDYN = $(ROOT)/$(BIN_DIR)/dynamic-$(RUN)

run : FORCE
	$(DATCPY)
	@if [ -x "$(RUNEXEDYN)" ]; then \
		echo "$(RUNEXEDYN)" && \
		$(RUNEXEDYN); \
	elif [ -x "$(RUNEXESTA)" ]; then \
		echo "$(RUNEXESTA)" && \
		$(RUNEXESTA); \
	else \
		echo "Could not find \"$(RUNEXESTA)\" or \"$(RUNEXEDYN)\""; \
	fi

# Read the docs!
rtd : FORCE
	$(OPEN) $(ROOT)/$(DOC_DIR)/index.html
	@#$(OPEN) $(ROOT)/$(DOC_DIR)/refman.pdf

clean-% : FORCE
	@if [ $(patsubst clean-%,%,$@) = $(DAT_DIR) ] || \
		[ $(patsubst clean-%,%,$@) = $(TST_DIR) ]; then \
		echo "I doubt you want to clean $(ROOT)/$(patsubst clean-%,%,$@). \
If you *really* want to, do it manually."; \
	elif [ $(patsubst clean-%,%,$@) = $(SRC_DIR) ]; then \
		echo "find $(ROOT)/$(SRC_DIR) -type f -name "*.o" -delete"; \
		find $(ROOT)/$(SRC_DIR) -type f -name "*.o" -delete; \
	else \
		echo "rm -rf $(ROOT)/$(patsubst clean-%,%,$@)"; \
		rm -rf $(ROOT)/$(patsubst clean-%,%,$@); \
	fi

clean-all : FORCE
	@$(MAKE) clean-$(BIN_DIR)
	@$(MAKE) clean-$(DOC_DIR)
	@$(MAKE) clean-$(INC_DIR)
	@$(MAKE) clean-$(LIB_DIR)
	@$(MAKE) clean-$(SRC_DIR)

clean : FORCE
	$(MAKE) clean-$(SRC_DIR)

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

# Usage example: `make open M=ezhello F=ezhello`
open : FORCE
	vim -O `find $(ROOT)/$(SRC_DIR)/$(M) -name $(F).*`

# Usage example: `make module M=game_engine F=window`
module : FORCE
	mkdir -p $(ROOT)/$(INC_DIR)/$(M)/`dirname $(F)`
	mkdir -p $(ROOT)/$(SRC_DIR)/$(M)/`dirname $(F)`
	@printf "\
	/*  $(F).$(H)\n\
	 *  \n\
	$(LICENSE)\n\
	 */\n\
	\n\
	#ifndef `basename $(F) | awk '{print toupper($$0)}'`_`echo $(H) | awk '{print toupper($$0)}'`\n\
	#define `basename $(F) | awk '{print toupper($$0)}'`_`echo $(H) | awk '{print toupper($$0)}'`\n\
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
	#endif /* `basename $(F) | awk '{print toupper($$0)}'`_`echo $(H) | awk '{print toupper($$0)}'` */\
	" >> $(ROOT)/$(INC_DIR)/$(M)/$(F).$(H)
	@printf "\
	/*  $(F).$(C)\n\
	 *  \n\
	$(LICENSE)\n\
	 */\n\
	\n\
	#include \"$(M)/$(F).$(H)\"\n\
	\n\
	\n\
	\n\
	int16_t `basename $(F) | awk '{print tolower($$0)}'`_example(int16_t alpha, int16_t beta)\n\
	{\n\
	    return alpha + beta;\n\
	}\
	" >> $(ROOT)/$(SRC_DIR)/$(M)/$(F).$(C)
	vim -O $(ROOT)/$(SRC_DIR)/$(M)/$(F).$(C) $(ROOT)/$(INC_DIR)/$(M)/$(F).$(H)

# Usage example: `make class M=GameEngine F=Window`
class : FORCE
	mkdir -p $(ROOT)/$(INC_DIR)/$(M)/`dirname $(F)`
	mkdir -p $(ROOT)/$(SRC_DIR)/$(M)/`dirname $(F)`
	@printf "\
	/*  $(M)/$(F).$(HPP)\n\
	 *  \n\
	$(LICENSE)\n\
	 */\n\
	\n\
	#ifndef `echo $(M) | awk '{print toupper($$0)}'`_\
	`basename $(F) | awk '{print toupper($$0)}'`_\
	`echo $(HPP) | awk '{print toupper($$0)}'`\n\
	#define `echo $(M) | awk '{print toupper($$0)}'`_\
	`basename $(F) | awk '{print toupper($$0)}'`_\
	`echo $(HPP) | awk '{print toupper($$0)}'`\n\
	\n\
	/** @file       $(M)/$(F).$(HPP)\n\
	 *  @brief      Lorem ipsum\n\
	 *  @details    Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n\
	 */\n\
	\n\
	// #include <memory>\n\
	\n\
	\n\
	\n\
	namespace $(M)\n\
	{\n\
	\n\
	/** @brief      Lorem ipsum\n\
	 *  @details    Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do\n\
	 *              eiusmod tempor incididunt ut labore et dolore magna aliqua.\n\
	 */\n\
	class $(F)\n\
	{\n\
	public:\n\
	    /** @brief      Lorem ipsum\n\
	     *  @details    Lorem ipsum dolor sit amet, consectetur adipiscing\n\
	     *              elit, sed do eiusmod tempor incididunt ut labore et\n\
	     *              dolore magna aliqua.\n\
	     */\n\
	    $(F)();\n\
	    $(F)($(F) const &other);\n\
	    $(F)& operator=($(F) const &other);\n\
	    virtual ~$(F)();\n\
	\n\
	protected:\n\
	\n\
	private:\n\
	\n\
	};\n\
	\n\
	}; /* namespace EzSDL */\n\
	\n\
	\n\
	\n\
	#endif /* `echo $(M) | awk '{print toupper($$0)}'`_\
	`basename $(F) | awk '{print toupper($$0)}'`_\
	`echo $(HPP) | awk '{print toupper($$0)}'` */\
	" >> $(ROOT)/$(INC_DIR)/$(M)/$(F).$(HPP)
	@printf "\
	/*  $(M)/$(F).$(CPP)\n\
	 *  \n\
	$(LICENSE)\n\
	 */\n\
	\n\
	#include \"$(M)/$(F).$(HPP)\"\n\
	\n\
	namespace $(M)\n\
	{\n\
	\n\
	\n\
	\n\
	$(F)::$(F)()\n\
	{\n\
	}\n\
	\n\
	\n\
	\n\
	$(F)::$(F)($(F) const &other)\n\
	{\n\
	}\n\
	\n\
	\n\
	\n\
	$(F)& $(F)::operator=($(F) const &other)\n\
	{\n\
	}\n\
	\n\
	\n\
	\n\
	$(F)::~$(F)()\n\
	{\n\
	}\n\
	\n\
	\n\
	\n\
	}; /* namespace $(M) */\
	" >> $(ROOT)/$(SRC_DIR)/$(M)/$(F).$(CPP)
	vim -O $(ROOT)/$(SRC_DIR)/$(M)/$(F).$(CPP) \
		$(ROOT)/$(INC_DIR)/$(M)/$(F).$(HPP)

# Usage example: `make main M=test_chat F=main.c T=chat_input_a`
main : FORCE
	mkdir -p $(ROOT)/$(SRC_DIR)/$(M)
	if [ $(T) ]; then mkdir -p $(ROOT)/$(TST_DIR)/$(M); fi
	@printf "\
	/*  $(M)/$(F)\n\
	 *  \n\
	$(LICENSE)\n\
	 */\n\
	\n\
	/** @file       $(F)\n\
	 *  @brief      Lorem ipsum\n\
	 *  @details    Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n\
	 */\n\
	\n\
	#include <stdio.h>\n\
	/* #include <cstdio> */\n\
	\n\
	\n\
	\n\
	/* Did you forget to specify the file extension in 'F=$(F)'?*/\n\
	\n\
	int main(int argc, char *argv[])\n\
	{\n\
	    printf(\"Hello world! This is \'$(basename $(F))\'.\\\n\");\n\
	    return 0;\n\
	}\
	" >> $(ROOT)/$(SRC_DIR)/$(M)/$(F)
	vim -O $(ROOT)/$(SRC_DIR)/$(M)/$(F) \
		`if [ $(T) ]; then printf $(ROOT)/$(TST_DIR)/$(M)/$(T); fi`


FORCE :
