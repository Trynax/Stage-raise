// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StageRaise} from "../../src/StageRaise.sol";
import {console} from "forge-std/console.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract StageRaiseIntegrationTest is Test {
    StageRaise stageRaise;
    HelperConfig helperConfig;
    
    address public PROJECT_OWNER = makeAddr("PROJECT_OWNER");
    address public FUNDER_1 = makeAddr("FUNDER_1");
    address public FUNDER_2 = makeAddr("FUNDER_2");
    address public FUNDER_3 = makeAddr("FUNDER_3");
    
    uint256 constant STARTING_BALANCE = 100 ether;
    uint256 constant PROJECT_TARGET = 10 ether;
    uint256 constant PROJECT_DEADLINE = 30 days;
    uint256 constant MILESTONE_COUNT = 5;
    uint256 constant VOTING_TIME = 7 days;
    uint256 constant MIN_FUNDING_USD = 1000e8; // $1000
    uint256 constant MAX_FUNDING_USD = 50000e8; // $50000

    event ProjectCreated(string indexed name, uint256 indexed targetAmount, uint256 indexed deadline);
    event ProjectFunded(string indexed name, uint256 indexed amountFunded, address indexed funder);
    event WithDrawnFromProject(string indexed name, uint256 indexed amountWithdrawn, address indexed Withdrawer);
    event ProjectOpenedForVoting(string indexed name, uint256 indexed timeOpenForVoting, uint256 indexed projectId);
    event ProjectVotingProcessFinalized(string indexed name, uint256 indexed projectById, bool indexed voteResult);
    event RefundRequested(string indexed projectName, uint256 indexed projectId, address indexed funder, uint256 refundAmount);

    function setUp() public {
        helperConfig = new HelperConfig();
        address ethUsdPriceFeed = helperConfig.activeNetworkConfig();
        stageRaise = new StageRaise(ethUsdPriceFeed);
        vm.deal(PROJECT_OWNER, STARTING_BALANCE);
        vm.deal(FUNDER_1, STARTING_BALANCE);
        vm.deal(FUNDER_2, STARTING_BALANCE);
        vm.deal(FUNDER_3, STARTING_BALANCE);
    }

   function testCompleteProjectLifecycleForMilestoneProject() public {
    vm.startPrank(PROJECT_OWNER);
    stageRaise.createProject(
        StageRaise.CreateProjectParams({
            name: "Decentralized Social Media",
            description: "Building the future of social media",
            targetAmount: PROJECT_TARGET,
            deadline: block.timestamp + PROJECT_DEADLINE,
            milestoneCount: MILESTONE_COUNT,
            milestoneBased: true,
            timeForMileStoneVotingProcess: VOTING_TIME,
            minFundingUSD: MIN_FUNDING_USD,
            maxFundingUSD: MAX_FUNDING_USD
        })
    );
    vm.stopPrank();
    
    uint256 projectId = 1;
    
    StageRaise.ProjectInfo memory projectInfo = stageRaise.getProjectBasicInfo(projectId);
    assertEq(projectInfo.name, "Decentralized Social Media");
    assertEq(projectInfo.targetAmount, PROJECT_TARGET);
    assertEq(projectInfo.milestoneCount, MILESTONE_COUNT);
    assertTrue(projectInfo.milestoneBased);
    assertEq(stageRaise.getProjectMilestoneStage(projectId), 1);

    // Fund the project
    vm.prank(FUNDER_1);
    stageRaise.fundProject{value: 4 ether}(projectId);
    
    vm.prank(FUNDER_2);
    stageRaise.fundProject{value: 3 ether}(projectId);
    
    vm.prank(FUNDER_3);
    stageRaise.fundProject{value: 2 ether}(projectId);
    
   
    assertEq(stageRaise.getProjectBasicInfo(projectId).raisedAmount, 9 ether);
    assertEq(stageRaise.getProjectBalance(projectId), 9 ether);
    assertEq(stageRaise.getProjectContributorAmount(projectId, FUNDER_1), 4 ether);
    assertEq(stageRaise.getProjectContributorAmount(projectId, FUNDER_2), 3 ether);
    assertEq(stageRaise.getProjectContributorAmount(projectId, FUNDER_3), 2 ether);

    vm.warp(block.timestamp + PROJECT_DEADLINE + 1);
    
    // Testing
    vm.startPrank(PROJECT_OWNER);
    uint256 withdrawableAmount = stageRaise.getAmountWithdrawableForAProject(projectId);
    assertEq(withdrawableAmount, 1.8 ether);  
    
    stageRaise.withdrawFunds(withdrawableAmount, projectId, payable(PROJECT_OWNER));
    vm.stopPrank();
 
    assertEq(stageRaise.getProjectAmountWithdrawn(projectId), withdrawableAmount);
    assertEq(stageRaise.getProjectBalance(projectId), 9 ether - withdrawableAmount);


    vm.startPrank(PROJECT_OWNER);
    stageRaise.openProjectForMilestoneVotes(projectId);
    vm.stopPrank();
    
    assertTrue(stageRaise.getProjectMileStoneVotingStatus(projectId));


    vm.prank(FUNDER_1);
    stageRaise.takeAVoteForMilestoneStageIncrease(projectId, true);
    
    vm.prank(FUNDER_2);
    stageRaise.takeAVoteForMilestoneStageIncrease(projectId, true);
    
    vm.prank(FUNDER_3);
    stageRaise.takeAVoteForMilestoneStageIncrease(projectId, true);
    
 
    uint256 funder1Power = stageRaise.calculateFunderVotingPower(FUNDER_1, projectId);
    uint256 funder2Power = stageRaise.calculateFunderVotingPower(FUNDER_2, projectId);
    uint256 funder3Power = stageRaise.calculateFunderVotingPower(FUNDER_3, projectId);
    
    
    assertEq(funder1Power, 444444444444444444);

    assertEq(funder2Power, 333333333333333333);

    assertEq(funder3Power, 222222222222222222);
    
    uint256 totalYesVotes = stageRaise.getProjectYesVotes(projectId);
    assertEq(totalYesVotes, funder1Power + funder2Power + funder3Power);
    
 
    vm.warp(block.timestamp + VOTING_TIME + 100);
    stageRaise.finalizeVotingProcess(projectId);

    assertEq(stageRaise.getProjectMilestoneStage(projectId), 2);
    assertFalse(stageRaise.getProjectMileStoneVotingStatus(projectId));
    assertEq(stageRaise.getProjectFailedMilestoneStage(projectId), 0);
    

    vm.startPrank(PROJECT_OWNER);
    uint256 newWithdrawableAmount = stageRaise.getAmountWithdrawableForAProject(projectId);
    assertEq(newWithdrawableAmount, 1.8 ether); // 1/5 
    
    stageRaise.withdrawFunds(newWithdrawableAmount, projectId, payable(PROJECT_OWNER));
    vm.stopPrank();


    vm.warp(block.timestamp + 1);

    vm.startPrank(PROJECT_OWNER);
    stageRaise.openProjectForMilestoneVotes(projectId);
    vm.stopPrank();
    

    uint256 votingEndTime = stageRaise.getProjectVotingEndTime(projectId);

    vm.prank(FUNDER_1);
    stageRaise.takeAVoteForMilestoneStageIncrease(projectId, false);
    
    vm.prank(FUNDER_2);
    stageRaise.takeAVoteForMilestoneStageIncrease(projectId, false);
    
    vm.prank(FUNDER_3);
    stageRaise.takeAVoteForMilestoneStageIncrease(projectId, false);
    

    vm.warp(votingEndTime + 100);
    console.log(block.timestamp, votingEndTime+100);
    stageRaise.finalizeVotingProcess(projectId);

    
    // Verify failed milestone
    assertEq(stageRaise.getProjectMilestoneStage(projectId), 2);
    assertEq(stageRaise.getProjectFailedMilestoneStage(projectId), 1); 

    for (uint256 i = 0; i < 2; i++) {
        vm.startPrank(PROJECT_OWNER);
        stageRaise.openProjectForMilestoneVotes(projectId);
        vm.stopPrank();
        
   
        uint256 votingEndTime = stageRaise.getProjectVotingEndTime(projectId);
        
        vm.prank(FUNDER_1);
        stageRaise.takeAVoteForMilestoneStageIncrease(projectId, false);
        
        vm.prank(FUNDER_2);
        stageRaise.takeAVoteForMilestoneStageIncrease(projectId, false);
    
        vm.warp(votingEndTime + 100);
        stageRaise.finalizeVotingProcess(projectId);
    }
    

    assertEq(stageRaise.getProjectFailedMilestoneStage(projectId), 3);
    
    // Testing refund mechanism
    uint256 funder1BalanceBefore = FUNDER_1.balance;
    uint256 funder2BalanceBefore = FUNDER_2.balance;
    
    vm.prank(FUNDER_1);
    stageRaise.requestRefund(projectId);
    
    vm.prank(FUNDER_2);
    stageRaise.requestRefund(projectId);

    uint256 funder1BalanceAfter = FUNDER_1.balance;
    uint256 funder2BalanceAfter = FUNDER_2.balance;
    
    assertTrue(funder1BalanceAfter > funder1BalanceBefore);
    assertTrue(funder2BalanceAfter > funder2BalanceBefore);
    

    assertEq(stageRaise.getProjectContributorAmount(projectId, FUNDER_1), 0);
    assertEq(stageRaise.getProjectContributorAmount(projectId, FUNDER_2), 0);
    
    console.log("Project went through complete lifecycle: creation -> funding -> milestones -> failures -> refunds");
}


function testCompleteProjectLifecycleForNonMilestoneProject() public {
   
        vm.startPrank(PROJECT_OWNER);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Simple Crowdfund",
                description: "Simple crowdfunding without milestones",
                targetAmount: 5 ether,
                deadline: block.timestamp + PROJECT_DEADLINE,
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: VOTING_TIME,
                minFundingUSD: MIN_FUNDING_USD,
                maxFundingUSD: MAX_FUNDING_USD
            })
        );
        vm.stopPrank();
        
        uint256 projectId = 1;
   
        vm.prank(FUNDER_1);
        stageRaise.fundProject{value: 2 ether}(projectId);
        
        vm.prank(FUNDER_2);
        stageRaise.fundProject{value: 1.5 ether}(projectId);

        vm.warp(block.timestamp + PROJECT_DEADLINE + 1);
        

        vm.startPrank(PROJECT_OWNER);
        uint256 withdrawableAmount = stageRaise.getAmountWithdrawableForAProject(projectId);
        assertEq(withdrawableAmount, 3.5 ether);
        
        stageRaise.withdrawFunds(withdrawableAmount, projectId, payable(PROJECT_OWNER));
        vm.stopPrank();
        
       
        assertEq(stageRaise.getProjectBalance(projectId), 0);
        assertEq(stageRaise.getProjectAmountWithdrawn(projectId), 3.5 ether);
        
        console.log("Non-milestone project lifecycle completed successfully!");
    }
    
    function testMultipleProjectsInteraction() public {
    
        vm.startPrank(PROJECT_OWNER);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Project Alpha",
                description: "First project",
                targetAmount: 5 ether,
                deadline: block.timestamp + PROJECT_DEADLINE,
                milestoneCount: 3,
                milestoneBased: true,
                timeForMileStoneVotingProcess: VOTING_TIME,
                minFundingUSD: MIN_FUNDING_USD,
                maxFundingUSD: MAX_FUNDING_USD
            })
        );
        vm.stopPrank();
        
        vm.startPrank(FUNDER_1);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Project Beta",
                description: "Second project",
                targetAmount: 3 ether,
                deadline: block.timestamp + PROJECT_DEADLINE,
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: VOTING_TIME,
                minFundingUSD: MIN_FUNDING_USD,
                maxFundingUSD: MAX_FUNDING_USD
            })
        );
        vm.stopPrank();
        
   
        vm.prank(FUNDER_2);
        stageRaise.fundProject{value: 2 ether}(1);
        
        vm.prank(FUNDER_3);
        stageRaise.fundProject{value: 1 ether}(2); 
        
        vm.prank(PROJECT_OWNER);
        stageRaise.fundProject{value: 1 ether}(2);
        

        assertEq(stageRaise.getProjectCount(), 2);
        assertEq(stageRaise.getProjectBasicInfo(1).raisedAmount, 2 ether);
        assertEq(stageRaise.getProjectBasicInfo(2).raisedAmount, 2 ether);
        
        console.log("Multiple projects interaction test completed!");
    }
    
    
}
    




