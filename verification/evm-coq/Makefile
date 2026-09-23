# Coq 8.20. bbv and coq-evm are fetched by deps.sh; see pins.txt.
BBV_SRC := deps/bbv/src/bbv
EVM_SRC := deps/coq-evm
COQC ?= coqc
COQBIN ?=
COQ_ARGS := -Q $(BBV_SRC) bbv -Q $(EVM_SRC) CoqEVM

.PHONY: all clean check deps

all: check

deps:
	./deps.sh

deps/bbv/src/bbv/Word.vo: deps
	$(MAKE) -C deps/bbv coq COQBIN=$(COQBIN)

deps/coq-evm/evmModel.vo: deps/bbv/src/bbv/Word.vo deps/coq-evm/evmModel.v
	$(COQBIN)$(COQC) $(COQ_ARGS) deps/coq-evm/evmModel.v

SimpleBankEVM.vo: deps/coq-evm/evmModel.vo SimpleBankEVM.v
	$(COQBIN)$(COQC) $(COQ_ARGS) SimpleBankEVM.v

check: SimpleBankEVM.vo
	grep -q "Closed under the global context" assumptions-deposit.txt.out
	grep -q "Closed under the global context" assumptions-nonzero.txt.out
	grep -q "Closed under the global context" assumptions-add.txt.out

clean:
	rm -f SimpleBankEVM.vo SimpleBankEVM.vok SimpleBankEVM.vos SimpleBankEVM.glob \
	  assumptions-deposit.txt.out assumptions-nonzero.txt.out assumptions-add.txt.out \
	  .SimpleBankEVM.aux .lia.cache
	if [ -f deps/coq-evm/evmModel.vo ]; then rm -f deps/coq-evm/evmModel.vo deps/coq-evm/evmModel.glob; fi
	if [ -d deps/bbv ]; then $(MAKE) -C deps/bbv clean || true; fi
