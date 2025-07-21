// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {StageRaise} from "../src/StageRaise.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployStageRaise is Script{

    function run () external returns (StageRaise, HelperConfig){
        HelperConfig helperConfig = new HelperConfig();
        address ethUsdPriceFeed = helperConfig.activeNetworkConfig();
        vm.startBroadcast();
        StageRaise stageRaise = new StageRaise(ethUsdPriceFeed);
        vm.stopBroadcast(); 

        return (stageRaise, helperConfig);     
    }
}