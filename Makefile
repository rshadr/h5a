#
# Copyright 2024 rshadr
# See LICENSE for details
#

all: build/libh5a.a build_tests

include config.mk

CFLAGS += -I./include

SOURCES =\
	character_queue\
	entities\
	parser\
	tokenizer\
	tokenizer_states\
	treebuilder

OBJS = $(patsubst %, build/%.o, $(SOURCES))

build/character_queue.o: src/character_queue.asm \
	src/local.inc src/util.inc
build/parser.o: src/parser.asm \
	src/local.inc src/util.inc
build/tokenizer.o: src/tokenizer.asm \
	src/local.inc src/util.inc
build/tokenizer_states.o: src/tokenizer_states.asm \
	src/tokenizer_states.g src/local.inc src/util.inc
build/treebuilder.o: src/treebuilder.asm \
	src/local.inc src/util.inc

TESTS =\
	default

TEST_BINS = $(patsubst %, build/test/%, $(TESTS))
TEST_DEPS = $(patsubst %, %.d, $(TEST_BINS))

-include $(TEST_DEPS)

build_tests: $(TEST_BINS)

build/libh5a.a: $(OBJS)
	@mkdir -p $(@D)
	$(AR) -rc $@ $^
	$(RANLIB) $@

build/%.o: src/%.asm
	@mkdir -p $(@D)
	$(FASM2) -v 2 $< $@

build/%.o: gen/%.asm
	@mkdir -p $(@D)
	$(FASM2) -v 2 $< $@

build/tools/%: tools/%.cc
	@mkdir -p $(@D)
	$(CXX) -o $@ -MMD $(CXXFLAGS) $<

gen/entities.asm: ext/entities.json build/tools/gen_entities
	@mkdir -p $(@D)
	build/tools/gen_entities ext/entities.json > $@

build/test/%: test/%.c build/libh5a.a
	@mkdir -p $(@D)
	$(CC) -o $@ -MMD $(CFLAGS) $< -L./build -lh5a -lgrapheme

clean:
	rm -rf build
	rm -rf gen

.PHONY: all clean

