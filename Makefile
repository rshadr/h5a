####
#### Copyright 2024 rshadr
#### See LICENSE for details
####

all: build/libh5a.a build_tests build_examples

include config.mk

CFLAGS += -I./include

SOURCES =\
	character_queue\
	entities\
	insertion_modes\
	parser\
	tokenizer\
	tokenizer_states\
	treebuilder\
	unicode\
	vectors

OBJS = $(patsubst %, build/%.o, $(SOURCES))

build/character_queue.o: src/character_queue.asm \
	src/local.inc src/util.inc
build/insertion_modes.o: src/insertion_modes.asm \
	src/insertion_modes.g src/local.inc src/util.inc
build/parser.o: src/parser.asm \
	src/local.inc src/util.inc
build/string.o: src/string.asm \
	src/local.inc src/util.inc
build/tokenizer.o: src/tokenizer.asm \
	src/local.inc src/util.inc
build/tokenizer_states.o: src/tokenizer_states.asm \
	src/tokenizer_states.g src/local.inc src/util.inc
build/treebuilder.o: src/treebuilder.asm \
	src/local.inc src/util.inc
build/vectors.o: src/vectors.asm \
  src/util.inc src/local.inc

TESTS =\
	character_queue\
	string

TEST_BINS = $(patsubst %, build/test/%, $(TESTS))
TEST_DEPS = $(patsubst %, %.d, $(TEST_BINS))

-include $(TEST_DEPS)

EXAMPLES =\
	minidom

EXAMPLE_BINS = $(patsubst %, build/examples/%, $(EXAMPLES))
EXAMPLE_DEPS = $(patsubst %, %.d, $(EXAMPLE_BINS))

-include $(EXAMPLE_DEPS)

build_tests: $(TEST_BINS)
build_examples: $(EXAMPLE_BINS)

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

build/examples/%: examples/%.c build/libh5a.a
	@mkdir -p $(@D)
	$(CC) -o $@ -MMD $(CFLAGS) $< -L./build -lh5a -lgrapheme

clean:
	rm -rf build
	rm -rf gen

.PHONY: all clean

