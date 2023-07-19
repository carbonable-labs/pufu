.PHONY: build test format declare

build:
	scarb build

format:
	scarb fmt

test:
	scarb test

declare:
	starkli declare target/dev/pufu_${CONTRACT}.sierra.json 

declare-pufu:
	$(MAKE) declare CONTRACT=pufu

declare-erc20:
	$(MAKE) declare CONTRACT=erc20

declare-erc721:
	$(MAKE) declare CONTRACT=erc721