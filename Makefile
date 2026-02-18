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

# Deployment (using keystore)
# First time setup: Create keystore with 'cast wallet import <account-name> --interactive'
# Then use the account name in deploy commands below

# Deploy to Anvil (local)
deploy-local:
	forge script script/DeployStageRaise.s.sol:DeployStageRaise --rpc-url http://localhost:8545 --broadcast -vvvv

# Deploy to BSC Testnet
deploy-bsc-testnet:
	@echo "Deploying to BSC Testnet..."
	@read -p "Enter your keystore account name: " ACCOUNT; \
	forge script script/DeployStageRaise.s.sol:DeployStageRaise \
		--rpc-url https://data-seed-prebsc-1-s1.binance.org:8545 \
		--account $$ACCOUNT \
		--broadcast \
		--verify \
		--etherscan-api-key ${BSCSCAN_API_KEY} \
		--legacy \
		-vvvv

# Deploy to BSC Testnet (alternative RPC)
deploy-bsc-testnet-alt:
	@echo "Deploying to BSC Testnet (Alternative RPC)..."
	@read -p "Enter your keystore account name: " ACCOUNT; \
	forge script script/DeployStageRaise.s.sol:DeployStageRaise \
		--rpc-url https://bsc-testnet.publicnode.com \
		--account $$ACCOUNT \
		--broadcast \
		--verify \
		--etherscan-api-key ${BSCSCAN_API_KEY} \
		--legacy \
		-vvvv

# Deploy to BSC Mainnet
deploy-bsc-mainnet:
	@echo "⚠️  WARNING: Deploying to BSC MAINNET ⚠️"
	@read -p "Enter your keystore account name: " ACCOUNT; \
	forge script script/DeployStageRaise.s.sol:DeployStageRaise \
		--rpc-url https://bsc-dataseed.binance.org \
		--account $$ACCOUNT \
		--broadcast \
		--verify \
		--etherscan-api-key ${BSCSCAN_API_KEY} \
		--legacy \
		-vvvv

# Deploy to Sepolia
deploy-sepolia:
	@echo "Deploying to Sepolia..."
	@read -p "Enter your keystore account name: " ACCOUNT; \
	forge script script/DeployStageRaise.s.sol:DeployStageRaise \
		--rpc-url ${SEPOLIA_RPC_URL} \
		--account $$ACCOUNT \
		--broadcast \
		--verify \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		-vvvv

# Verify contract on BSCScan (if auto-verify failed)
verify-bsc:
	@echo "Verifying on BSCScan..."
	@read -p "Enter contract address: " CONTRACT; \
	@read -p "Enter USDC address: " USDC; \
	@read -p "Enter USDT address: " USDT; \
	@read -p "Enter BUSD address: " BUSD; \
	forge verify-contract $$CONTRACT \
		src/StageRaise.sol:StageRaise \
		--chain-id 97 \
		--constructor-args $$(cast abi-encode "constructor(address,address,address)" $$USDC $$USDT $$BUSD) \
		--etherscan-api-key ${BSCSCAN_API_KEY} \
		--watch
