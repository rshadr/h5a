#
# Copyright 2024 rshadr
# See LICENSE for details
#

all: build/libh5a.a

include config.mk

SOURCES =\
	tokenizer\
	tokenizer_states\
	treebuilder

OBJS = $(patsubst %, build/%.o, $(SOURCES))

build/tokenizer.o: src/tokenizer.asm src/local.inc src/util.inc
build/treebuilder.o: src/treebuilder.asm src/local.inc src/util.inc

build/libh5a.a: $(OBJS)
	@mkdir -p $(@D)
	$(AR) -rc $@ $^
	$(RANLIB) $@

build/%.o: src/%.asm
	@mkdir -p $(@D)
	$(FASM2) $< $@

clean:
	rm -rf build

.PHONY: all clean

