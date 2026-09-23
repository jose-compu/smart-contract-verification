# Coq 8.20. See README.md.
.PHONY: all clean check

all: check

SimpleBank.vo: SimpleBank.v
	coqc SimpleBank.v

check: SimpleBank.vo
	grep -q "Closed under the global context" assumptions-P4.txt.out
	grep -q "Closed under the global context" assumptions-P2.txt.out

clean:
	rm -f SimpleBank.vo SimpleBank.vok SimpleBank.vos SimpleBank.glob \
	  assumptions-P4.txt.out assumptions-P2.txt.out .SimpleBank.aux .lia.cache
