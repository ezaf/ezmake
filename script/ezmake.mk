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

# Source subdirecties and files
SRC_SUBDIRS_MAIN = $(foreach DIR,$(MAINS),$(SRC_DIR)/$(DIR))
SRC_SUBDIRS_MODULE = $(foreach DIR,$(MODULES),$(SRC_DIR)/$(DIR))
SRC_SUBDIRS_ALL = $(SRC_SUBDIRS_MAIN) $(SRC_SUBDIRS_MODULE) \
				  $(foreach DIR,$(SUB_SUBDIRS),$(SUB_DIR)/$(DIR))
SRC_FILES_ALL = $(foreach EXT,$(SRC_EXTS), \
					$(foreach DIR,$(SRC_SUBDIRS_ALL), \
						$(wildcard $(DIR)/*.$(EXT))))

# Source subdirecties and files
INC_SUBDIRS_ALL = $(foreach DIR,$(SRC_SUBDIRS_ALL), \
					  $(patsubst ./$(SRC_DIR)/%,./$(INC_DIR)%,$(FILE)))
INC_FILES_ALL = $(foreach EXT,$(INC_EXTS), \
					$(foreach DIR,$(SRC_SUBDIRS_ALL), \
						$(wildcard $(DIR)/*.$(EXT))))
INC_DESTS_ALL = $(foreach FILE,$(INC_FILES_ALL), \
					$(patsubst ./$(SRC_DIR)/%,./$(INC_DIR)%,$(FILE)))

# Include and library flags
CF += -fPIC -I$(ROOT)/$(SRC_DIR) \
	 $(foreach DIR,$(SUB_SUBDIRS),-I$(ROOT)/$(SUB_DIR)/$(DIR)) \
	 $(foreach DIR,$(PREFIXES),-I$(DIR)/include)
LF += $(foreach DIR,$(PREFIXES) $(ROOT),-L$(DIR)/lib)

# Package flags
ifneq ($(PKGS),)
	CF += `pkg-config --cflags --silence-errors $(PKGS)`
	LF_TEMP := $(LF)
	LF = `pkg-config --libs --silence-errors $(PKGS)` $(LF_TEMP)
endif

# Find what OS we're on so we can better configure all the compiler options.
# All compiler flags can be customized on a per-platform basis.
# Linux->"Linux" | MacOS->"Darwin" | Windows->"*_NT-*"
ifneq (, $(shell uname -s | grep -E _NT))
	CULT = windows
	DYN_EXT = dll
	EXE_EXT = exe
	# Uncomment to remove console window
	CF += #-Wl,-subsystem,windows
	# -lmingw32 and -lOpenGL32 must come before everything else
	LF_TEMP := $(LF)
	LF = -lmingw32 $(if $(filter glew glfw3,$(PKGS)), -lOpenGL32) $(LF_TEMP)
	OPEN = cmd //c start "${@//&/^&}"
endif
ifneq (, $(shell uname -s | grep -E Linux))
	CULT = linux
	DYN_EXT = so
	EXE_EXT = out
	CF +=
	LF += -lX11 -lXxf86vm -lXrandr -lpthread -lXi -lm -ldl -lXinerama -lXcursor
	OPEN = xdg-open
endif
ifneq (, $(shell uname -s | grep -E Darwin))
	CULT = macos
	DYN_EXT = dylib
	EXE_EXT = app
	OPEN =
	# TODO: flesh out build system for MacOS
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
reverse = $(if $(1),$(call reverse,$(wordlist 2,$(words $(1)),$(1)))) \
		  $(firstword $(1))

# File extension substitute (abstraction of patsubst)
extsubst = $(patsubst %.$(firstword $(1)),%.$(2), \
		   $(if $(filter-out $(firstword $(1)), $(1)), \
		       $(call extsubst,$(filter-out $(firstword $(1)),$(1)), \
			       $(2),$(3)), \
			   $(3)))

# Get all obj|inc of module parameter
objofmod = $(call extsubst,$(SRC_EXTS),o,$(foreach EXT,$(SRC_EXTS), \
			   $(wildcard $(ROOT)/$(SRC_DIR)/$(1)/*.$(EXT))))

incofmod = $(foreach EXT,$(INC_EXTS), \
			   $(wildcard $(ROOT)/$(SRC_DIR)/$(1)/*.$(EXT)))

# For %.d : %.c?? -> %.o
deptoobj = @set -e; rm -f $(1); $(CC) $(CF) -M $(2) >$(1).$$$$; \
		   sed 's,^.*\.o[ :]*,$(basename $(1)).o : ,g' < $(1).$$$$ > $(1); \
		   printf "\t$(CC) $(CF) -c $(2) $(LF) -o $(basename $(1)).o\n">>$(1);\
		   rm -f $(1).$$$$



###############################################################################
##################################  Targets  ##################################
###############################################################################

help :
	@echo "TODO: Write help documentation."

# %.o : deps -> %.d
-include $(call extsubst,$(SRC_EXTS),d,$(SRC_FILES_ALL))

# %.d : %.c?? -> %.o
%.d : %.c
	$(call deptoobj,$@,$<)

%.d : %.cc
	$(call deptoobj,$@,$<)

%.d : %.cpp
	$(call deptoobj,$@,$<)

%.d : %.cxx
	$(call deptoobj,$@,$<)

%.d : %.c++
	$(call deptoobj,$@,$<)

$(MODULES) $(MAINS) : FORCE
	@# Nothing needed here.

$(BIN_DIR) : FORCE
	@$(foreach MOD,$(MODULES), \
		printf "$(MAKE) $@/$(MOD).$(DYN_EXT)\n"; \
		$(MAKE) $@/$(MOD).$(DYN_EXT);)

$(DAT_DIR) $(SRC_DIR) :
	mkdir -p $(ROOT)/$@

$(DOC_DIR) : $(INC_FILES_ALL)
	@$(MAKE) clean-$@
	mkdir -p $(ROOT)/$@
	@$(MAKE) $(SUB_DIR)
	doxygen >/dev/null

$(INC_DIR) : FORCE
	@$(foreach DIR,$(MODULES), \
		printf "$(MAKE) $@/$(DIR)\n"; \
		$(MAKE) $@/$(DIR);)

$(LIB_DIR) : FORCE
	@$(foreach MOD,$(MODULES), \
		printf "$(MAKE) $@/lib$(MOD).a\n"; \
		$(MAKE) $@/lib$(MOD).a;)

$(SUB_DIR) : FORCE
	mkdir -p $(ROOT)/$@
	git submodule update --init --remote --force

.SECONDEXPANSION :
$(BIN_DIR)/%.$(DYN_EXT) : $$(call objofmod,%)
	@$(if $(filter $*,$(MODULES)), \
		mkdir -p $(ROOT)/$(BIN_DIR); \
			printf "$(CC) $(CF) -shared $^ $(LF) -o $(ROOT)/$@\n"; \
			$(CC) $(CF) -shared $^ $(LF) \
				$(filter-out $(ROOT)/$@, \
					$(wildcard $(ROOT)/$(BIN_DIR)/*.$(DYN_EXT))) \
				-o $(ROOT)/$@, \
		printf "'$*' is not in MODULES\n")

.SECONDEXPANSION :
$(BIN_DIR)/static-%.$(EXE_EXT) : $$(call objofmod,%) \
		$(foreach MOD,$(call reverse,$(MODULES)), \
			$(ROOT)/$(LIB_DIR)/lib$(MOD).a)
	@$(if $(filter $*,$(MAINS)), \
		mkdir -p $(ROOT)/$(BIN_DIR); \
			printf "$(CC) $(CF) $^ $(LF) -o $(ROOT)/$@\n"; \
			$(CC) $(CF) $^ $(LF) -o $(ROOT)/$@, \
		printf "'$*' is not in MAINS\n")

.SECONDEXPANSION :
$(BIN_DIR)/dynamic-%.$(EXE_EXT) : $$(call objofmod,%) \
		$(foreach MOD,$(call reverse,$(MODULES)), \
			$(ROOT)/$(BIN_DIR)/$(MOD).$(DYN_EXT))
	@$(if $(filter $*,$(MAINS)), \
		mkdir -p $(ROOT)/$(BIN_DIR); \
			printf "$(CC) $(CF) $^ $(LF) -o $(ROOT)/$@\n"; \
			$(CC) $(CF) $^ $(LF) -o $(ROOT)/$@, \
		printf "'$*' is not in MAINS\n")

.SECONDEXPANSION :
$(INC_DIR)/% : $$(call incofmod,%)
	@mkdir -p $(ROOT)/$(INC_DIR)
	@mkdir -p $(ROOT)/$(basename $@)
	$(foreach FILE,$?, \
		cp $(ROOT)/$(FILE) \
			$(ROOT)/$(patsubst $(SRC_DIR)/%,$(INC_DIR)/%,$(FILE));)

.SECONDEXPANSION :
$(LIB_DIR)/lib%.a : $$(call objofmod,%)
	@$(if $(filter $*,$(MODULES)), \
		mkdir -p $(ROOT)/$(LIB_DIR); \
			printf "ar rcs $(ROOT)/$@ $?\n"; \
			ar rcs $(ROOT)/$@ $?;, \
		printf "'$*' is not in MODULES\n")

all : FORCE
	@$(foreach MOD,$(MODULES), \
		$(MAKE) $(LIB_DIR)/lib$(MOD).a; \
		$(MAKE) $(INC_DIR)/$(MOD); \
		$(MAKE) $(BIN_DIR)/$(MOD).$(DYN_EXT);)
	@$(foreach MAIN,$(MAINS), \
		$(MAKE) $(BIN_DIR)/static-$(MAIN).$(EXE_EXT); \
		$(MAKE) $(BIN_DIR)/dynamic-$(MAIN).$(EXE_EXT);)
	@#$(MAKE) $(DOC_DIR)

# Read the docs!
rtd : FORCE
	$(OPEN) $(ROOT)/$(DOC_DIR)/index.html
	@#$(OPEN) $(ROOT)/$(DOC_DIR)/refman.pdf

DATCPY = $(if $(wildcard $(ROOT)/$(DAT_DIR)), \
		 cp -r -u $(ROOT)/$(DAT_DIR) $(ROOT)/$(BIN_DIR))

test : FORCE
	@$(MAKE) all
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
				$(ROOT)/$(BIN_DIR)/$(SD)-$(T).$(EXE_EXT) < $(INPUT) && \
			))) echo
	@echo "== END TESTING =="

RUNEXESTA = $(ROOT)/$(BIN_DIR)/static-$(RUN).$(EXE_EXT)
RUNEXEDYN = $(ROOT)/$(BIN_DIR)/dynamic-$(RUN).$(EXE_EXT)

run : FORCE
	@$(MAKE) all
	$(DATCPY)
	@bash -c "if [[ -x \"$(RUNEXEDYN)\" ]]; then \
		echo \"$(RUNEXEDYN)\" && \
		$(RUNEXEDYN); \
	elif [[ -x \"$(RUNEXESTA)\" ]]; then \
		echo \"$(RUNEXESTA)\" && \
		$(RUNEXESTA); \
	else \
		echo \"Could not find \\\"$(RUNEXESTA)\\\" or \\\"$(RUNEXEDYN)\\\"\"; \
	fi"

clean-% : FORCE
	$(if $(findstring $(patsubst clean-%,%,$@),$(DAT_DIR) $(TST_DIR)), \
		@printf "I doubt you want to clean '$(ROOT)/$(patsubst clean-%,%,$@)'. \
Do it manually if you *really* want to.\n", \
		$(if $(findstring $(patsubst clean-%,%,$@),$(SRC_DIR)), \
			find $(ROOT)/$(SRC_DIR) -type f \
				\( -name "*.o" -or -name "*.d" -or -name "*.d.*" \) -delete, \
			rm -rf $(patsubst clean-%,%,$@)))

clean : FORCE
	@$(MAKE) clean-$(BIN_DIR)
	@$(MAKE) clean-$(DOC_DIR)
	@$(MAKE) clean-$(INC_DIR)
	@$(MAKE) clean-$(LIB_DIR)
	@$(MAKE) clean-$(SRC_DIR)



###############################################################################
##############################  File Templates  ###############################
###############################################################################

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
	vim -O $(filter $(foreach EXT,$(INC_EXTS) $(SRC_EXTS),%$(EXT)), \
			$(if $(M), \
				$(wildcard $(ROOT)/$(SRC_DIR)/$(M)/$(F).*), \
				$(foreach DIR,$(MODULES) $(MAINS), \
					$(wildcard $(ROOT)/$(SRC_DIR)/$(DIR)/$(F).*))))

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
	@bash -c "if [[ $(T) ]]; then mkdir -p $(ROOT)/$(TST_DIR)/$(M); fi"
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
	int main(int argc, char *argv[[]])\n\
	{\n\
	    printf(\"Hello world! This is \'$(basename $(F))\'.\\\n\");\n\
	    return 0;\n\
	}\
	" >> $(ROOT)/$(SRC_DIR)/$(M)/$(F)
	vim -O $(ROOT)/$(SRC_DIR)/$(M)/$(F) \
		`if [[ $(T) ]]; then printf $(ROOT)/$(TST_DIR)/$(M)/$(T); fi`

.SUFFIXES :

FORCE :
