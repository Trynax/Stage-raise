// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {StageRaise} from "../src/StageRaise.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

error DeployStageRaise__InvalidTokenConfig();

contract DeployStageRaise is Script {
    function run() external returns (StageRaise, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (address usdc, address usdt, address busd) = helperConfig.activeNetworkConfig();

        if (usdc == address(0) || usdt == address(0) || busd == address(0)) {
            revert DeployStageRaise__InvalidTokenConfig();
        }
        
        vm.startBroadcast();
        StageRaise stageRaise = new StageRaise(usdc, usdt, busd);
        vm.stopBroadcast();

        return (stageRaise, helperConfig);
    }
}
