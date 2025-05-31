SPEC = p4spectec
EXESPEC = p4spec/_build/default/bin/main.exe

# Compile

.PHONY: build build-spec build-spectec


build: build-spec


build-spec:
	rm -f ./$(SPEC)
	opam switch 4.14.0
	cd p4spec && opam exec -- dune build bin/main.exe && echo
	ln -f $(EXESPEC) ./$(SPEC)

# Format

.PHONY: fmt

fmt:
	opam switch 4.14.0
	cd p4spec && opam exec dune fmt

# Cleanup

.PHONY: clean

clean:
	rm -f ./$(MAIN) ./$(SPEC)
	cd p4spec && dune clean
