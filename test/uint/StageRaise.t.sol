// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;


import {Test} from "forge-std/Test.sol";
import {StageRaise } from "../../src/StageRaise.sol";

error StageRaise__DeadlineMustBeInFuture();
error StageRaise__TargetAmountMustBeGreaterThanZero();
error StageRaise__AmountToFundMustBeGreaterThanZero();
error StageRaise__ProjectNotActive();
error StageRaise__ProjectNotFound();
error StageRaise__TotalRaiseCantSurpassTargetRaise();
contract StageRaiseTest is Test{
    StageRaise stageRaise;
    function setUp() public {
        stageRaise = new StageRaise();
         stageRaise.createProject(
            "Stage Raise", "decentralized crowdfunding", 2 ether, block.timestamp +20000, true,5, true
        );
        stageRaise.createProject(
            "Stage Raise 2", "decentralized crowdfunding 2", 3 ether, block.timestamp +30000, true,5, true
        );

    }   

    // Testing fuctions

    function testCreateProject () external{
       stageRaise.createProject(
            "Stage Raise3", "decentralized crowdfunding3", 2 ether, block.timestamp +20000, true,5, true
        );
        (,string memory name,,,,,,,,) = stageRaise.getProjectBasicInfo(1);

        assert(keccak256(bytes(name)) == keccak256(bytes("Stage Raise3")));
    }


    function testFundProject() external {
        stageRaise.fundProject{value:1 ether}(1);

        (,,,,uint256 raisedAmount,,,,,)=stageRaise.getProjectBasicInfo(1);

        assert(raisedAmount == 1 ether);
    }


    // Testing View and Pure Function 
    function testGetProjectCount () external {

        uint256 projectCount = stageRaise.getProjectCount();

        assertEq(projectCount, 2);
    }
    // Testing Errors 

    function testCreatingProjectDeadlineMustBeInFuture() external{
        vm.expectRevert(StageRaise__DeadlineMustBeInFuture.selector);
        stageRaise.createProject(
            "Stage Raise3", "decentralized crowdfunding3", 2 ether, block.timestamp, true,5, true
        );
   }

   function testCreatingProjectWithZeroTargetAmount() external{
    vm.expectRevert(StageRaise__TargetAmountMustBeGreaterThanZero.selector);

     stageRaise.createProject(
            "Stage Raise3", "decentralized crowdfunding3", 0, block.timestamp+200, true,5, true
        );
   }



}