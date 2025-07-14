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
    event ProjectCreated (string indexed name, uint256 indexed targetAmount, uint256 indexed deadline);
    event ProjectFunded (string indexed name, uint256 indexed AmoutFunded, address indexed Funder);
    StageRaise stageRaise;
    address TRYNAX = makeAddr("TRYNAX");

    function setUp() public {
        stageRaise = new StageRaise();
            
        vm.deal(TRYNAX, 10 ether);
         stageRaise.createProject(
            "Stage Raise", "decentralized crowdfunding", 2 ether, block.timestamp +20000, true,5, true
        );
         stageRaise.createProject(
            "Stage Raise 2", "decentralized crowdfunding 2", 3 ether, block.timestamp +30000, true,5, true
        );
        stageRaise.createProject(
            "Stage Raise 3", "decentralized crowdfunding 3", 2 ether, block.timestamp +20000, true,5, true
        );
       
        stageRaise.createProject(
            "Stage Raise 4", "decentralized crowdfunding 4", 3 ether, block.timestamp +30000, false,5, true
        );
        stageRaise.createProject(
            "Stage Raise 5", "decentralized crowdfunding 5", 3 ether, block.timestamp +30000, true,5, true
        );

    }   

    // Testing fuctions

    function testCreateProject () external{
       
        (,string memory name,,,,,,,,) = stageRaise.getProjectBasicInfo(1);

        assert(keccak256(bytes(name)) == keccak256(bytes("Stage Raise")));
    }


    function testFundProject() external {
        stageRaise.fundProject{value:1 ether}(1);

        (,,,,uint256 raisedAmount,,,,,)=stageRaise.getProjectBasicInfo(1);

        assert(raisedAmount == 1 ether);
        assert(address(stageRaise).balance == 1 ether);
    }


    // Testing View and Pure Function 
    function testGetProjectCount () external {

        uint256 projectCount = stageRaise.getProjectCount();

        assertEq(projectCount, 5);
    }
    // Testing Errors 

    function testCreatingProjectDeadlineMustBeInFuture() external{
        vm.expectRevert(StageRaise__DeadlineMustBeInFuture.selector);
        stageRaise.createProject(
            "Stage Raise 6", "decentralized crowdfunding 6", 2 ether, block.timestamp, true,5, true
        );
   }

   function testCreatingProjectWithZeroTargetAmount() external{
    vm.expectRevert(StageRaise__TargetAmountMustBeGreaterThanZero.selector);

     stageRaise.createProject(
            "Stage Raise 7", "decentralized crowdfunding 7", 0, block.timestamp+200, true,5, true
        );
   }


   function testFundProjectWithZero() external {
    vm.expectRevert(StageRaise__AmountToFundMustBeGreaterThanZero.selector);
    stageRaise.fundProject{value:0}(1);
   }

   function testFundingNonExistingProject() external {
    vm.expectRevert(StageRaise__ProjectNotFound.selector);
    stageRaise.fundProject{value:2 ether}(100);

   }

   function testFundingNonActiveProject() external {
    vm.expectRevert(StageRaise__ProjectNotActive.selector);
    stageRaise.fundProject{value: 1 ether}(4);
   }


   function testFundingProjectWithAmountGreaterThanTarget() external{
    vm.expectRevert(StageRaise__TotalRaiseCantSurpassTargetRaise.selector);

    stageRaise.fundProject{
        value:100 ether
    }(1);

   }


   // Testing Events 

   function testProjectCreatedEvents() external{

    vm.warp(2000);
    uint256 deadline = 4000;

    vm.expectEmit(true, true, true, false);
    emit ProjectCreated("Credula", 10 ether, deadline);
        stageRaise.createProject(
            "Credula", "decentralized crowdfunding", 10 ether, deadline, true,5, true
        );
   }

   function testProjectFundedEvents() external{
    
    vm.expectEmit(true, true, true, false);
    emit ProjectFunded("Stage Raise", 1 ether,address(TRYNAX) );

    vm.prank(TRYNAX);
    stageRaise.fundProject{value: 1 ether}(1);
   }



}