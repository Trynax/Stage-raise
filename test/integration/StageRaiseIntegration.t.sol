// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StageRaise} from "../../src/StageRaise.sol";
import {console} from "forge-std/console.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract StageRaiseIntegrationTest is Test {
    StageRaise stageRaise;
    HelperConfig helperConfig;
    MockERC20 usdc;
    MockERC20 usdt;
    MockERC20 busd;

    address public PROJECT_OWNER = makeAddr("PROJECT_OWNER");
    address public FUNDER_1 = makeAddr("FUNDER_1");
    address public FUNDER_2 = makeAddr("FUNDER_2");
    address public FUNDER_3 = makeAddr("FUNDER_3");

    uint256 constant STARTING_BALANCE = 100000e6; // 100k USDC/USDT
    uint256 constant STARTING_BALANCE_BUSD = 100000e18; // 100k BUSD
    uint96 constant PROJECT_TARGET = 10000e18; // 10k in 18 decimals
    uint64 constant PROJECT_DEADLINE = 30 days;
    uint8 constant MILESTONE_COUNT = 5;
    uint64 constant VOTING_TIME = 7 days;
    uint96 constant MIN_FUNDING = 1000e18; // $1000 in 18 decimals
    uint96 constant MAX_FUNDING = 50000e18; // $50000 in 18 decimals

    event ProjectCreated(
        string indexed name, uint96 indexed targetAmount, uint64 indexed fundingStart, uint64 fundingEnd
    );
    event ProjectFunded(string indexed name, uint96 indexed amountFunded, address indexed funder);
    event WithDrawnFromProject(string indexed name, uint96 indexed amountWithdrawn, address indexed Withdrawer);
    event ProjectOpenedForVoting(string indexed name, uint64 indexed timeOpenForVoting, uint32 indexed projectId);
    event ProjectVotingProcessFinalized(string indexed name, uint32 indexed projectById, bool indexed voteResult);
    event RefundRequested(
        string indexed projectName, uint32 indexed projectId, address indexed funder, uint96 refundAmount
    );

    function setUp() public {
        helperConfig = new HelperConfig();
        (address usdcAddr, address usdtAddr, address busdAddr) = helperConfig.activeNetworkConfig();
        stageRaise = new StageRaise(usdcAddr, usdtAddr, busdAddr);
        
        usdc = MockERC20(usdcAddr);
        usdt = MockERC20(usdtAddr);
        busd = MockERC20(busdAddr);
        
        // Mint tokens to test users
        usdc.mint(PROJECT_OWNER, STARTING_BALANCE);
        usdc.mint(FUNDER_1, STARTING_BALANCE);
        usdc.mint(FUNDER_2, STARTING_BALANCE);
        usdc.mint(FUNDER_3, STARTING_BALANCE);
        
        usdt.mint(PROJECT_OWNER, STARTING_BALANCE);
        usdt.mint(FUNDER_1, STARTING_BALANCE);
        usdt.mint(FUNDER_2, STARTING_BALANCE);
        usdt.mint(FUNDER_3, STARTING_BALANCE);
        
        busd.mint(PROJECT_OWNER, STARTING_BALANCE_BUSD);
        busd.mint(FUNDER_1, STARTING_BALANCE_BUSD);
        busd.mint(FUNDER_2, STARTING_BALANCE_BUSD);
        busd.mint(FUNDER_3, STARTING_BALANCE_BUSD);
        
        // Approve stageRaise for all users
        vm.startPrank(PROJECT_OWNER);
        usdc.approve(address(stageRaise), type(uint256).max);
        usdt.approve(address(stageRaise), type(uint256).max);
        busd.approve(address(stageRaise), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(FUNDER_1);
        usdc.approve(address(stageRaise), type(uint256).max);
        usdt.approve(address(stageRaise), type(uint256).max);
        busd.approve(address(stageRaise), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(FUNDER_2);
        usdc.approve(address(stageRaise), type(uint256).max);
        usdt.approve(address(stageRaise), type(uint256).max);
        busd.approve(address(stageRaise), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(FUNDER_3);
        usdc.approve(address(stageRaise), type(uint256).max);
        usdt.approve(address(stageRaise), type(uint256).max);
        busd.approve(address(stageRaise), type(uint256).max);
        vm.stopPrank();
    }

    function testCompleteProjectLifecycleForMilestoneProject() public {
        vm.startPrank(PROJECT_OWNER);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Decentralized Social Media",
                description: "Building the future of social media",
                targetAmount: PROJECT_TARGET,
                fundingStart: uint64(block.timestamp),
                fundingEnd: uint64(block.timestamp) + PROJECT_DEADLINE,
                milestoneCount: MILESTONE_COUNT,
                milestoneBased: true,
                timeForMileStoneVotingProcess: VOTING_TIME,
                minFunding: MIN_FUNDING,
                maxFunding: MAX_FUNDING,
                paymentToken: address(usdc)
            })
        );
        vm.stopPrank();

        uint32 projectId = 1;

        StageRaise.ProjectInfo memory projectInfo = stageRaise.getProjectBasicInfo(projectId);
        assertEq(projectInfo.name, "Decentralized Social Media");
        assertEq(projectInfo.targetAmount, PROJECT_TARGET);
        assertEq(projectInfo.milestoneCount, MILESTONE_COUNT);
        assertTrue(projectInfo.milestoneBased);
        assertEq(stageRaise.getProjectMilestoneStage(projectId), 1);

        // Fund the project
        vm.prank(FUNDER_1);
        stageRaise.fundProject(projectId, 4000e6); // 4000 USDC

        vm.prank(FUNDER_2);
        stageRaise.fundProject(projectId, 3000e6); // 3000 USDC

        vm.prank(FUNDER_3);
        stageRaise.fundProject(projectId, 2000e6); // 2000 USDC

        assertEq(stageRaise.getProjectBasicInfo(projectId).raisedAmount, 9000e18); // Normalized
        assertEq(stageRaise.getProjectBalance(projectId), 9000e18); // Balance is also normalized internally
        assertEq(stageRaise.getProjectContributorAmount(projectId, FUNDER_1), 4000e18); // Normalized
        assertEq(stageRaise.getProjectContributorAmount(projectId, FUNDER_2), 3000e18); // Normalized
        assertEq(stageRaise.getProjectContributorAmount(projectId, FUNDER_3), 2000e18); // Normalized

        vm.warp(block.timestamp + PROJECT_DEADLINE + 1);

        // Testing
        vm.startPrank(PROJECT_OWNER);
        uint96 withdrawableAmount = stageRaise.getAmountWithdrawableForAProject(projectId);
        assertEq(withdrawableAmount, 1800e6); // 20% of 9000 USDC = 1800 USDC

        stageRaise.withdrawFunds(withdrawableAmount, projectId, payable(PROJECT_OWNER));
        vm.stopPrank();

        assertEq(stageRaise.getProjectAmountWithdrawn(projectId), 1800e18); // Stored normalized
        assertEq(stageRaise.getProjectBalance(projectId), 9000e18 - 1800e18); // Balance normalized

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

        assertEq(funder1Power, 444444444444444444); // 4000/9000 = 44.44%

        assertEq(funder2Power, 333333333333333333); // 3000/9000 = 33.33%

        assertEq(funder3Power, 222222222222222222); // 2000/9000 = 22.22%

        uint256 totalYesVotes = stageRaise.getProjectYesVotes(projectId);
        assertEq(totalYesVotes, funder1Power + funder2Power + funder3Power);

        vm.warp(block.timestamp + VOTING_TIME + 100);
        stageRaise.finalizeVotingProcess(projectId);

        assertEq(stageRaise.getProjectMilestoneStage(projectId), 2);
        assertFalse(stageRaise.getProjectMileStoneVotingStatus(projectId));
        assertEq(stageRaise.getProjectFailedMilestoneStage(projectId), 0);

        vm.startPrank(PROJECT_OWNER);
        uint96 newWithdrawableAmount = stageRaise.getAmountWithdrawableForAProject(projectId);
        assertEq(newWithdrawableAmount, 1800e6); // 20% of 9000 = 1800 USDC

        stageRaise.withdrawFunds(newWithdrawableAmount, projectId, payable(PROJECT_OWNER));
        vm.stopPrank();

        vm.warp(block.timestamp + 1);

        vm.startPrank(PROJECT_OWNER);
        stageRaise.openProjectForMilestoneVotes(projectId);
        vm.stopPrank();

        uint64 votingEndTime = stageRaise.getProjectVotingEndTime(projectId);

        vm.prank(FUNDER_1);
        stageRaise.takeAVoteForMilestoneStageIncrease(projectId, false);

        vm.prank(FUNDER_2);
        stageRaise.takeAVoteForMilestoneStageIncrease(projectId, false);

        vm.prank(FUNDER_3);
        stageRaise.takeAVoteForMilestoneStageIncrease(projectId, false);

        vm.warp(votingEndTime + 100);
        console.log(block.timestamp, votingEndTime + 100);
        stageRaise.finalizeVotingProcess(projectId);

        // Verify failed milestone
        assertEq(stageRaise.getProjectMilestoneStage(projectId), 2);
        assertEq(stageRaise.getProjectFailedMilestoneStage(projectId), 1);

        for (uint256 i = 0; i < 2; i++) {
            vm.startPrank(PROJECT_OWNER);
            stageRaise.openProjectForMilestoneVotes(projectId);
            vm.stopPrank();

            uint64 loopVotingEndTime = stageRaise.getProjectVotingEndTime(projectId);

            vm.prank(FUNDER_1);
            stageRaise.takeAVoteForMilestoneStageIncrease(projectId, false);

            vm.prank(FUNDER_2);
            stageRaise.takeAVoteForMilestoneStageIncrease(projectId, false);

            vm.warp(loopVotingEndTime + 100);
            stageRaise.finalizeVotingProcess(projectId);
        }

        assertEq(stageRaise.getProjectFailedMilestoneStage(projectId), 3);

        // Testing refund mechanism
        uint256 funder1BalanceBefore = usdc.balanceOf(FUNDER_1);
        uint256 funder2BalanceBefore = usdc.balanceOf(FUNDER_2);

        vm.prank(FUNDER_1);
        stageRaise.requestRefund(projectId);

        vm.prank(FUNDER_2);
        stageRaise.requestRefund(projectId);

        uint256 funder1BalanceAfter = usdc.balanceOf(FUNDER_1);
        uint256 funder2BalanceAfter = usdc.balanceOf(FUNDER_2);

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
                targetAmount: 5000e18, // 5k in 18 decimals
                fundingStart: uint64(block.timestamp),
                fundingEnd: uint64(block.timestamp) + PROJECT_DEADLINE,
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: VOTING_TIME,
                minFunding: MIN_FUNDING,
                maxFunding: MAX_FUNDING,
                paymentToken: address(usdc)
            })
        );
        vm.stopPrank();

        uint32 projectId = 1;

        vm.prank(FUNDER_1);
        stageRaise.fundProject(projectId, 2000e6); // 2000 USDC

        vm.prank(FUNDER_2);
        stageRaise.fundProject(projectId, 1500e6); // 1500 USDC

        vm.warp(block.timestamp + PROJECT_DEADLINE + 1);

        vm.startPrank(PROJECT_OWNER);
        uint96 withdrawableAmount = stageRaise.getAmountWithdrawableForAProject(projectId);
        assertEq(withdrawableAmount, 3500e6); // 3500 USDC

        stageRaise.withdrawFunds(withdrawableAmount, projectId, payable(PROJECT_OWNER));
        vm.stopPrank();

        assertEq(stageRaise.getProjectBalance(projectId), 0);
        assertEq(stageRaise.getProjectAmountWithdrawn(projectId), 3500e18); // Stored normalized

        console.log("Non-milestone project lifecycle completed successfully!");
    }

    function testMultipleProjectsInteraction() public {
        vm.startPrank(PROJECT_OWNER);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Project Alpha",
                description: "First project",
                targetAmount: 5000e18,
                fundingStart: uint64(block.timestamp),
                fundingEnd: uint64(block.timestamp) + PROJECT_DEADLINE,
                milestoneCount: 3,
                milestoneBased: true,
                timeForMileStoneVotingProcess: VOTING_TIME,
                minFunding: MIN_FUNDING,
                maxFunding: MAX_FUNDING,
                paymentToken: address(usdc)
            })
        );
        vm.stopPrank();

        vm.startPrank(FUNDER_1);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Project Beta",
                description: "Second project",
                targetAmount: 3000e18,
                fundingStart: uint64(block.timestamp),
                fundingEnd: uint64(block.timestamp) + PROJECT_DEADLINE,
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: VOTING_TIME,
                minFunding: MIN_FUNDING,
                maxFunding: MAX_FUNDING,
                paymentToken: address(usdc)
            })
        );
        vm.stopPrank();

        vm.prank(FUNDER_2);
        stageRaise.fundProject(1, 2000e6); // 2000 USDC

        vm.prank(FUNDER_3);
        stageRaise.fundProject(2, 1000e6); // 1000 USDC

        vm.prank(PROJECT_OWNER);
        stageRaise.fundProject(2, 1000e6); // 1000 USDC

        assertEq(stageRaise.getProjectCount(), 2);
        assertEq(stageRaise.getProjectBasicInfo(1).raisedAmount, 2000e18); // Normalized
        assertEq(stageRaise.getProjectBasicInfo(2).raisedAmount, 2000e18); // Normalized

        console.log("Multiple projects interaction test completed!");
    }
}
