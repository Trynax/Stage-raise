# Makefile for StageRaise project

-include .env

# Default target
.PHONY: help
help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Build
.PHONY: build
build: ## Build the project
	forge build

# Clean
.PHONY: clean
clean: ## Clean build artifacts
	forge clean

# Install dependencies
.PHONY: install
install: ## Install dependencies
	forge install

# Update dependencies
.PHONY: update
update: ## Update dependencies
	forge update

# Test commands
.PHONY: test
test: ## Run all unit tests with local mock
	forge test

.PHONY: test-unit
test-unit: ## Run only unit tests
	forge test --match-path "**/unit/**"

.PHONY: test-integration
test-integration: ## Run integration tests (requires fork)
	forge test --match-path "**/integration/**" --fork-url $(SEPOLIA_RPC_URL)

.PHONY: test-coverage
test-coverage: ## Run tests with coverage report
	forge coverage

.PHONY: test-gas
test-gas: ## Run tests with gas reporting
	forge test --gas-report

# Deploy commands
.PHONY: deploy-anvil
deploy-anvil: ## Deploy to local Anvil
	forge script script/DeployStageRaise.s.sol:DeployStageRaise --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

.PHONY: deploy-sepolia
deploy-sepolia: ## Deploy to Sepolia testnet
	forge script script/DeployStageRaise.s.sol:DeployStageRaise --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)

# Verification
.PHONY: verify
verify: ## Verify contract on Etherscan
	forge verify-contract $(CONTRACT_ADDRESS) src/StageRaise.sol:StageRaise --etherscan-api-key $(ETHERSCAN_API_KEY) --rpc-url $(SEPOLIA_RPC_URL)

# Local development
.PHONY: anvil
anvil: ## Start local Anvil node
	anvil

# Price feed testing
.PHONY: test-price-feeds
test-price-feeds: ## Test price feed functionality specifically
	forge test --match-test "testGetUSDValue\|testGetETHValue\|testUSDLimits" -v

# Snapshot
.PHONY: snapshot
snapshot: ## Create gas snapshot
	forge snapshot

# Format
.PHONY: format
format: ## Format code
	forge fmt

# Lint
.PHONY: lint
lint: ## Lint code
	forge fmt --check
