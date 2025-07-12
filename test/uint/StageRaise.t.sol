// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;


import {Test} from "forge-std/Test.sol";
import {StageRaise } from "../../src/StageRaise.sol";


contract StageRaiseTest is Test{
    StageRaise stageRaise;
    function setUp() public {
        stageRaise = new StageRaise();
    }   


    function testCreateProject () external{
        stageRaise.createProject(
            "Stage Raise", "decentralized crowdfunding", 2 ether, block.timestamp +20000, true,5, true
        );

        (,string memory name,,,,,,,,) = stageRaise.getProjectBasicInfo(1);

        assert(keccak256(bytes(name)) == keccak256(bytes("Stage Raise")));
    }


}