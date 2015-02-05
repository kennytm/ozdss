all: $(addprefix build/,$(addsuffix .ozf,$(basename $(notdir $(wildcard src/*.oz)))))

test: all build/TestRunner.ozf
	@cd build && ozengine TestRunner.ozf *Test.ozf

clean:
	rm -f build/*.ozf

build/%.ozf: src/%.oz
	ozc -c -g -o $@ $^

.PHONY: all clean test

