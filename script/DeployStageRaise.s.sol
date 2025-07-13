// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

import {StageRaise} from "../src/StageRaise.sol";



contract DeployStageRaise is Script{

    function run () external returns (StageRaise){
        vm.startBroadcast();
        StageRaise stageRaise = new StageRaise();

        vm.stopBroadcast(); 

        return stageRaise;     
    }
}