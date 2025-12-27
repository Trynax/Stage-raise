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
