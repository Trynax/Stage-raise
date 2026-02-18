// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address usdc;
        address usdt;
        address busd;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getMainnetEthConfig();
        } else if (block.chainid == 97) {
            activeNetworkConfig = getBscTestnetConfig();
        } else if (block.chainid == 56) {
            activeNetworkConfig = getBscMainnetConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            usdc: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238, // Sepolia USDC
            usdt: 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0, // Sepolia USDT
            busd: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238  // Using USDC as BUSD placeholder
        });
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            usdc: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            usdt: 0xdAC17F958D2ee523a2206206994597C13D831ec7,
            busd: 0x4Fabb145d64652a948d72533023f6E7A623C7C53
        });
    }

    function getBscTestnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            usdc: 0x64544969ed7EBf5f083679233325356EbE738930, // BSC Testnet USDC
            usdt: 0x337610d27c682E347C9cD60BD4b3b107C9d34dDd, // BSC Testnet USDT
            busd: 0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee  // BSC Testnet BUSD
        });
    }

    function getBscMainnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            usdc: 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d, // BSC Mainnet USDC
            usdt: 0x55d398326f99059fF775485246999027B3197955, // BSC Mainnet USDT
            busd: 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56  // BSC Mainnet BUSD
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.usdc != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();

        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        MockERC20 usdt = new MockERC20("Tether USD", "USDT", 6);
        MockERC20 busd = new MockERC20("Binance USD", "BUSD", 18);

        vm.stopBroadcast();

        return NetworkConfig({usdc: address(usdc), usdt: address(usdt), busd: address(busd)});
    }
}
