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
	forge test --match-path "**/integration/**" --fork-url $(SEPOLIA_RPC_URL)

coverage:
	forge coverage

# Deploy
deploy-local:
	forge script script/DeployStageRaise.s.sol:DeployStageRaise --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

deploy-sepolia:
	forge script script/DeployStageRaise.s.sol:DeployStageRaise --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)

# Local node
anvil:
	anvil

# Code quality
format:
	forge fmt
