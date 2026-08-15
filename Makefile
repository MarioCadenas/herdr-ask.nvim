NVIM ?= nvim

test:
	@NVIM=$(NVIM) tests/run.sh

.PHONY: test
