# StageRaise Makefile
-include .env

# Build & Clean
build:
	forge build

clean:
	forge clean

# Dependencies
install:
	forge install

# Testing
test:
	forge test

test-unit:
	forge test --match-path "**/uint/**"

test-integration:
	forge test --match-path "**/integration/**" 

test-fork-sepolia: 
	forge test --fork-url ${SEPOLIA_RPC_URL}
test-fork-mainnet:
	forge test --fork-url ${MAINNET_RPC_URL}
coverage:
	forge coverage

# Local node
anvil:
	anvil

# Code quality
format:
	forge fmt
