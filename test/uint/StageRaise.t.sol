// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;


import {Test} from "forge-std/Test.sol";
import {StageRaise } from "../../src/StageRaise.sol";
import {console} from "forge-std/console.sol";

error StageRaise__DeadlineMustBeInFuture();
error StageRaise__TargetAmountMustBeGreaterThanZero();
error StageRaise__AmountToFundMustBeGreaterThanZero();
error StageRaise__AmountToWithdrawMustBeGreaterThanZero();
error StageRaise__ProjectNotActive();
error StageRaise__ProjectNotFound();
error StageRaise__TotalRaiseCantSurpassTargetRaise();
error StageRaise__DeadlineForFundingHasPassed();
error StageRaise__FundsCanOnlyBeWithdrawByProjectOwner();
error StageRaise__ETHTransferFailed();
error StageRaise__YouCannotWithdrawFromActiveProject();
error StageRaise__YouCannotWithdrawMoreThanTheProjectBalance();
error StageRaise__YouCannotHaveZeroMilestoneForAMileStoneProject();
error StageRaise__YouCannotWithdrawMoreThanWithdrawableBalance();
error StageRaise__AddressHasNotFundTheProject();
error StageRaise__CanOnlyBeCalledByProjectOwner();
error StageRaise__ProjectIsNotOpenForMilestoneVotingProcess();
error StageRaise__VotingProcessFormilestoneMustBeInFuture(); 
error StageRaise__FunderHasAlreadyVoted();
error StageRaise__TimeHasNotPassedForTheVotingProcess(); 
error StageRaise__VotingPeriodHasPassed(); 
error StageRaise__ProjectHasReachedTheFinalMileStoneStage(); 

contract StageRaiseTest is Test{
    event ProjectCreated (string indexed name, uint256 indexed targetAmount, uint256 indexed deadline);
    event ProjectFunded (string indexed name, uint256 indexed AmoutFunded, address indexed Funder);
    StageRaise stageRaise;
    address TRYNAX = makeAddr("TRYNAX");

    function setUp() public {
        stageRaise = new StageRaise();
            
        vm.deal(TRYNAX, 10 ether);
         stageRaise.createProject(
            "Stage Raise", "decentralized crowdfunding", 2 ether, block.timestamp +20000,5, true,200
        );
         stageRaise.createProject(
            "Stage Raise 2", "decentralized crowdfunding 2", 3 ether, block.timestamp +30000,5, true,200
        );
        stageRaise.createProject(
            "Stage Raise 3", "decentralized crowdfunding 3", 2 ether, block.timestamp +20000,5, true,200
        );
       
        stageRaise.createProject(
            "Stage Raise 4", "decentralized crowdfunding 4", 3 ether, block.timestamp +30000,5, true,200
        );
        stageRaise.createProject(
            "Stage Raise 5", "decentralized crowdfunding 5", 3 ether, block.timestamp +30000,5, true,200
        );

    }   

    // Testing fuctions

    function testCreateProject () external{
       
        string memory name  = stageRaise.getProjectBasicInfo(1).name;

        assert(keccak256(bytes(name)) == keccak256(bytes("Stage Raise")));
    }


    function testFundProject() external {
        stageRaise.fundProject{value:1 ether}(1);

        uint256 raisedAmount =stageRaise.getProjectBasicInfo(1).raisedAmount;

        assert(raisedAmount == 1 ether);
        assert(address(stageRaise).balance == 1 ether);
    }

    function testWithdrawFunds() external {
        vm.startPrank(TRYNAX);
         stageRaise.createProject(
            "Stage Raise 6", "decentralized crowdfunding 6", 2 ether, block.timestamp +20000,5, false,200
        );
        stageRaise.fundProject{value:1 ether}(6);
         vm.warp(block.timestamp+2000000);
        stageRaise.withdrawFunds(1 ether,6, payable(TRYNAX));
        vm.stopPrank();

        assert(stageRaise.getProjectBalance(6)==0);
      
       
    }

    function testopeningProjectForVoting() external {
        vm.warp(block.timestamp+200000);
        stageRaise.openProjectForMilestoneVotes(1);
        
        assert(stageRaise.getProjectMileStoneVotingStatus(1)==true);

    }



    function testForTakingAVote() external {

        vm.prank(TRYNAX);
        stageRaise.fundProject{value:1 ether}(1);
        vm.warp(block.timestamp+2000000);
        stageRaise.openProjectForMilestoneVotes(1);

        vm.startPrank(TRYNAX);
        stageRaise.takeAVoteForMilestoneStageIncrease(1,true);
        vm.stopPrank();
        assert(stageRaise.getProjectYesVotes(1)==stageRaise.calculateFunderVotingPower(TRYNAX, 1));


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
            "Stage Raise 6", "decentralized crowdfunding 6", 2 ether, block.timestamp,5, true,200
        );
   }

   function testCreatingProjectWithZeroTargetAmount() external{
    vm.expectRevert(StageRaise__TargetAmountMustBeGreaterThanZero.selector);

     stageRaise.createProject(
            "Stage Raise 7", "decentralized crowdfunding 7", 0, block.timestamp+200,5, true,200
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

 

   function testFundingProjectWithAmountGreaterThanTarget() external{
    vm.expectRevert(StageRaise__TotalRaiseCantSurpassTargetRaise.selector);

    stageRaise.fundProject{
        value:100 ether
    }(1);

   }

   function testFundingProjectThatDeadlineHasPassed() external {
    vm.warp(block.timestamp+20002);
    vm.expectRevert(StageRaise__DeadlineForFundingHasPassed.selector);
    stageRaise.fundProject{value:1 ether}(1);
   }


   // Testing Events 

   function testProjectCreatedEvents() external{

    vm.warp(2000);
    uint256 deadline = 4000;

    vm.expectEmit(true, true, true, false);
    emit ProjectCreated("Credula", 10 ether, deadline);
        stageRaise.createProject(
            "Credula", "decentralized crowdfunding", 10 ether, deadline,5, true,200
        );
   }

   function testProjectFundedEvents() external{
    
    vm.expectEmit(true, true, true, false);
    emit ProjectFunded("Stage Raise", 1 ether,address(TRYNAX) );

    vm.prank(TRYNAX);
    stageRaise.fundProject{value: 1 ether}(1);


   }



}