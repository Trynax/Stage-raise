// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StageRaise} from "../../src/StageRaise.sol";
import {console} from "forge-std/console.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

error StageRaise__DeadlineMustBeInFuture();
error StageRaise__TargetAmountMustBeGreaterThanZero();
error StageRaise__AmountToFundMustBeGreaterThanZero();
error StageRaise__ProjectNotActive();
error StageRaise__ProjectNotFound();
error StageRaise__TotalRaiseCantSurpassTargetRaise();
error StageRaise__DeadlineForFundingHasPassed();
error StageRaise__FundsCanOnlyBeWithdrawByProjectOwner();
error StageRaise__ETHTransferFailed();
error StageRaise__AmountToWithdrawMustBeGreaterThanZero();
error StageRaise__YouCannotWithdrawFromActiveProject();
error StageRaise__YouCannotWithdrawMoreThanTheProjectBalance();
error StageRaise__YouCannotHaveZeroMilestoneForAMileStoneProject();
error StageRaise__YouCannotWithdrawMoreThanWithdrawableBalance();
error StageRaise__AddressHasNotFundTheProject();
error StageRaise__FundingAmountAboveMaximum();
error StageRaise__FundingAmountBelowMinimum();
error StageRaise__CanOnlyBeCalledByProjectOwner();
error StageRaise__ProjectIsNotOpenForMilestoneVotingProcess();
error StageRaise__VotingProcessFormilestoneMustBeInFuture();
error StageRaise__FunderHasAlreadyVoted();
error StageRaise__TimeHasNotPassedForTheVotingProcess();
error StageRaise__VotingPeriodHasPassed();
error StageRaise__CannotWithdrawWhileFundingIsActive();
error StageRaise__ProjectHasReachedTheFinalMileStoneStage();
error StageRaise__YoucannotWWithdrawWhileFundingIsStillOn();
error StageRaise__YouCannotOpenNonMilestoneProjectForVoting();
error StageRaise__YouCannotOpenProjectVotingWhileFundingIsOngoing();
error StageRaise__RefundIsNotAllowed();
error StageRaise__ProjectHasFailedTooManyMilestones();

contract StageRaiseTest is Test {
    event ProjectCreated(string indexed name, uint88 indexed targetAmount, uint64 indexed deadline);
    event ProjectFunded(string indexed name, uint88 indexed AmoutFunded, address indexed Funder);
    event WithDrawnFromProject(string indexed name, uint88 indexed amountWithdrawn, address indexed Withdrawer);

    event ProjectOpenedForVoting(string indexed name, uint64 indexed timeOpenForVoting, uint32 indexed projectId);

    event ProjectVotingProcessFinalized(string indexed name, uint32 indexed projectById, bool indexed voteResult);

    event RefundRequested(
        string indexed projectName, uint32 indexed projectId, address indexed funder, uint88 refundAmount
    );

    StageRaise stageRaise;
    address TRYNAX = payable(makeAddr("TRYNAX"));

    function setUp() public {
        HelperConfig helperConfig = new HelperConfig();
        address ethUsdPriceFeed = helperConfig.activeNetworkConfig();
        stageRaise = new StageRaise(ethUsdPriceFeed);

        vm.deal(TRYNAX, 10 ether);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Stage Raise",
                description: "decentralized crowdfunding",
                targetAmount: 10 ether,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 5,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $1000
                maxFundingUSD: 50000e8 // $50000
            })
        );
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Stage Raise 2",
                description: "decentralized crowdfunding 2",
                targetAmount: 3 ether,
                deadline: uint64(block.timestamp + 30000),
                milestoneCount: 5,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $1000
                maxFundingUSD: 50000e8 // $50000
            })
        );
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Stage Raise 3",
                description: "decentralized crowdfunding 3",
                targetAmount: 2 ether,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 5,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $1000
                maxFundingUSD: 50000e8 // $50000
            })
        );

        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Stage Raise 4",
                description: "decentralized crowdfunding 4",
                targetAmount: 3 ether,
                deadline: uint64(block.timestamp + 30000),
                milestoneCount: 5,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $1000
                maxFundingUSD: 50000e8 // $50000
            })
        );
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Stage Raise 5",
                description: "decentralized crowdfunding 5",
                targetAmount: 3 ether,
                deadline: uint64(block.timestamp + 30000),
                milestoneCount: 5,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $1000
                maxFundingUSD: 50000e8 // $50000
            })
        );
    }

    // Testing fuctions

    function testCreateProject() external {
        string memory name = stageRaise.getProjectBasicInfo(1).name;

        assert(keccak256(bytes(name)) == keccak256(bytes("Stage Raise")));
    }

    function testFundProject() external {
        stageRaise.fundProject{value: 1 ether}(1);

        uint256 raisedAmount = stageRaise.getProjectBasicInfo(1).raisedAmount;
          console.log(address(stageRaise).balance, raisedAmount);

        assert(raisedAmount == 1 ether);
        assert(address(stageRaise).balance == 1 ether);

      
    }

    function testWithdrawFunds() external {
        vm.startPrank(TRYNAX);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Stage Raise 6",
                description: "decentralized crowdfunding 6",
                targetAmount: 2 ether,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $1000
                maxFundingUSD: 50000e8 // $50000
            })
        );
        stageRaise.fundProject{value: 1 ether}(6);
        vm.warp(block.timestamp + 2000000);
        stageRaise.withdrawFunds(1 ether, 6, payable(TRYNAX));
        vm.stopPrank();

        assert(stageRaise.getProjectBalance(6) == 0);
    }

    function testopeningProjectForVoting() external {
        vm.warp(block.timestamp + 200000);
        stageRaise.openProjectForMilestoneVotes(1);

        assert(stageRaise.getProjectMileStoneVotingStatus(1) == true);
    }

    function testForTakingAVote() external {
        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 1 ether}(1);
        vm.warp(block.timestamp + 2000000);
        stageRaise.openProjectForMilestoneVotes(1);

        vm.startPrank(TRYNAX);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, true);
        vm.stopPrank();
        assert(stageRaise.getProjectYesVotes(1) == stageRaise.calculateFunderVotingPower(TRYNAX, 1));
        assert(stageRaise.getProjectNoVotes(1) == 0);
    }

    function testFinalizeVotingProcess() external {
        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 1 ether}(1);
        vm.warp(block.timestamp + 20000000);

        stageRaise.openProjectForMilestoneVotes(1);

        vm.startPrank(TRYNAX);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, true);
        vm.stopPrank();
        vm.warp(block.timestamp + 20000);
        stageRaise.finalizeVotingProcess(1);
        assert(stageRaise.getProjectMilestoneStage(1) == 2);
        assert(stageRaise.getProjectMileStoneVotingStatus(1) == false);
    }

    function testVotingNo() external {
        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 1 ether}(1);

        vm.warp(block.timestamp + 25000);
        stageRaise.openProjectForMilestoneVotes(1);

        vm.prank(TRYNAX);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, false);

        assert(stageRaise.getProjectNoVotes(1) == stageRaise.calculateFunderVotingPower(TRYNAX, 1));
        assert(stageRaise.getProjectYesVotes(1) == 0);
    }

    function testRequestRefundAfterThreeFailures() external {
        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 2 ether}(1);

        vm.warp(block.timestamp + 25000);
        stageRaise.openProjectForMilestoneVotes(1);
        vm.prank(TRYNAX);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, true);
        vm.warp(block.timestamp + 300);
        stageRaise.finalizeVotingProcess(1);

        stageRaise.withdrawFunds(400000000000000000, 1, payable(address(this)));

        for (uint256 i = 0; i < 3; i++) {
            vm.warp(block.timestamp + 25000);
            stageRaise.openProjectForMilestoneVotes(1);

            vm.prank(TRYNAX);
            stageRaise.takeAVoteForMilestoneStageIncrease(1, false);

            vm.warp(block.timestamp + 300);
            stageRaise.finalizeVotingProcess(1);
        }

        uint256 balanceBefore = TRYNAX.balance;
        vm.prank(TRYNAX);
        stageRaise.requestRefund(1);
        uint256 balanceAfter = TRYNAX.balance;

        assert(balanceAfter > balanceBefore);

        uint256 contributorAmount = stageRaise.getProjectContributorAmount(1, TRYNAX);
        assert(contributorAmount == 0);
    }

    function testGetAmountWithdrawableForNonExistentProject() external {
        uint256 withdrawable = stageRaise.getAmountWithdrawableForAProject(999);
        assert(withdrawable == 0);
    }

    // Testing View and Pure Function
    function testGetProjectCount() external {
        uint256 projectCount = stageRaise.getProjectCount();

        assertEq(projectCount, 5);
    }

    function testGetEthPrice() external {
        uint256 ethPrice = stageRaise.getEthPrice();

        assert(ethPrice > 0);
    }

    function testGetAggregatorDecimals() external {
        uint8 decimals = stageRaise.getAggregatorDecimals();

        assertEq(decimals, 8);
    }

    function testGetUSDValue() external {
        uint256 ethAmount = 1 ether;
        uint256 usdValue = stageRaise.getUSDValue(ethAmount);
        assert(usdValue >= 2000e8);
    }

    function testGetETHValue() external {
        uint256 usdAmount = 2000e8;
        uint256 ethValue = stageRaise.getETHValue(usdAmount);

        assert(ethValue > 0);
    }

    function testGetProjectMinFundingUSD() external {
        uint256 minFunding = stageRaise.getProjectMinFundingUSD(1);
        assertEq(minFunding, 1000e8);
    }

    function testGetProjectMaxFundingUSD() external {
        uint256 maxFunding = stageRaise.getProjectMaxFundingUSD(1);
        assertEq(maxFunding, 50000e8);
    }

    function testGetAmountWithdrawableForNonMilestoneProject() external {
        vm.startPrank(TRYNAX);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Non-Milestone Project",
                description: "No milestones",
                targetAmount: 5 ether,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $1000
                maxFundingUSD: 50000e8 // $50000
            })
        );

        stageRaise.fundProject{value: 3 ether}(6);
        vm.stopPrank();

        uint256 withdrawable = stageRaise.getAmountWithdrawableForAProject(6);
        assert(withdrawable == 3 ether);
    }

    function testGetAmountWithdrawableForMilestoneProject() external {
        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 4 ether}(1);

        uint256 withdrawable = stageRaise.getAmountWithdrawableForAProject(1);
        assert(withdrawable == 800000000000000000);
    }

    function testGetProjectAmountWithdrawn() external {
        vm.startPrank(TRYNAX);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Withdrawal Test",
                description: "Test amount withdrawn",
                targetAmount: 5 ether,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $1000
                maxFundingUSD: 50000e8 // $50000
            })
        );

        stageRaise.fundProject{value: 3 ether}(6);
        vm.warp(block.timestamp + 25000);
        stageRaise.withdrawFunds(1 ether, 6, payable(TRYNAX));
        vm.stopPrank();

        uint256 amountWithdrawn = stageRaise.getProjectAmountWithdrawn(6);
        assert(amountWithdrawn == 1 ether);
    }

    function testGetProjectFailedMilestoneStage() external {
        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 1 ether}(1);

        vm.warp(block.timestamp + 25000);
        stageRaise.openProjectForMilestoneVotes(1);

        vm.prank(TRYNAX);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, false);

        vm.warp(block.timestamp + 300);
        stageRaise.finalizeVotingProcess(1);

        uint256 failedStages = stageRaise.getProjectFailedMilestoneStage(1);
        assert(failedStages == 1);
    }

    function testGetProjectContributorAmount() external {
        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 2 ether}(1);

        uint256 contributorAmount = stageRaise.getProjectContributorAmount(1, TRYNAX);
        assert(contributorAmount == 2 ether);

        address nonContributor = makeAddr("NON_CONTRIBUTOR");
        uint256 nonContributorAmount = stageRaise.getProjectContributorAmount(1, nonContributor);
        assert(nonContributorAmount == 0);
    }

    // Testing Errors

    function testCreatingProjectDeadlineMustBeInFuture() external {
        vm.expectRevert(StageRaise__DeadlineMustBeInFuture.selector);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Stage Raise 6",
                description: "decentralized crowdfunding 6",
                targetAmount: 2 ether,
                deadline: uint64(block.timestamp),
                milestoneCount: 5,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $1000
                maxFundingUSD: 50000e8 // $50000
            })
        );
    }

    function testCreatingProjectWithZeroTargetAmount() external {
        vm.expectRevert(StageRaise__TargetAmountMustBeGreaterThanZero.selector);

        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Stage Raise 7",
                description: "decentralized crowdfunding 7",
                targetAmount: 0,
                deadline: uint64(block.timestamp + 200),
                milestoneCount: 5,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $1000
                maxFundingUSD: 50000e8 // $50000
            })
        );
    }

    function testFundProjectWithZero() external {
        vm.expectRevert(StageRaise__AmountToFundMustBeGreaterThanZero.selector);
        stageRaise.fundProject{value: 0}(1);
    }

    function testFundingNonExistingProject() external {
        vm.expectRevert(StageRaise__ProjectNotFound.selector);
        stageRaise.fundProject{value: 2 ether}(100);
    }

    function testFundingProjectWithAmountAboveMaxUSD() external {
        vm.expectRevert(StageRaise__FundingAmountAboveMaximum.selector);

        stageRaise.fundProject{value: 100 ether}(1);
    }

    function testFundingProjectWithAmountBelowMinUSD() external {
        vm.expectRevert(StageRaise__FundingAmountBelowMinimum.selector);
        stageRaise.fundProject{value: 0.001 ether}(1);
    }

    function testFundingProjectWithAmountGreaterThanTarget() external {
        vm.expectRevert(StageRaise__TotalRaiseCantSurpassTargetRaise.selector);

        stageRaise.fundProject{value: 3 ether}(3);
    }

    function testFundingProjectThatDeadlineHasPassed() external {
        vm.warp(block.timestamp + 20002);
        vm.expectRevert(StageRaise__DeadlineForFundingHasPassed.selector);
        stageRaise.fundProject{value: 1 ether}(1);
    }

    function testWithdrawingByNonOwner() external {
        vm.startPrank(TRYNAX);
        stageRaise.fundProject{value: 5 ether}(1);
        vm.warp(block.timestamp + 200000);
        vm.expectRevert(StageRaise__CanOnlyBeCalledByProjectOwner.selector);
        stageRaise.withdrawFunds(1 ether, 1, payable(TRYNAX));
        vm.stopPrank();
    }

    function testWithdrawingZeroAmount() external {
        stageRaise.fundProject{value: 5 ether}(1);
        vm.warp(block.timestamp + 200000);
        vm.expectRevert(StageRaise__AmountToWithdrawMustBeGreaterThanZero.selector);
        stageRaise.withdrawFunds(0, 1, payable(TRYNAX));
    }

    function testCreatingProjectWithMilestoneWithZeroMilestoneCount() external {
        vm.expectRevert(StageRaise__YouCannotHaveZeroMilestoneForAMileStoneProject.selector);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Credula",
                description: "Testing.... ",
                targetAmount: 10 ether,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 0,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $1000
                maxFundingUSD: 50000e8 // $50000
            })
        );
    }

    function testFundingInactiveProject() external {
        vm.warp(block.timestamp + 50000);
        vm.expectRevert(StageRaise__DeadlineForFundingHasPassed.selector);
        stageRaise.fundProject{value: 1 ether}(1);
    }

    function testWithdrawMoreThanProjectBalance() external {
        vm.startPrank(TRYNAX);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Test Project",
                description: "Test description",
                targetAmount: 5 ether,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $10
                maxFundingUSD: 10000e8 // $1000
            })
        );

        stageRaise.fundProject{value: 2 ether}(6);
        vm.warp(block.timestamp + 25000);

        vm.expectRevert(StageRaise__YouCannotWithdrawMoreThanTheProjectBalance.selector);
        stageRaise.withdrawFunds(3 ether, 6, payable(TRYNAX));
        vm.stopPrank();
    }

    function testWithdrawMoreThanWithdrawableBalance() external {
        vm.startPrank(TRYNAX);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Milestone Test",
                description: "Test milestone project",
                targetAmount: 5 ether,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 4,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $1000
                maxFundingUSD: 50000e8 // $50000
            })
        );

        stageRaise.fundProject{value: 4 ether}(6);
        vm.warp(block.timestamp + 25000);

        vm.expectRevert(StageRaise__YouCannotWithdrawMoreThanWithdrawableBalance.selector);
        stageRaise.withdrawFunds(2 ether, 6, payable(TRYNAX));
        vm.stopPrank();
    }

    function testNonFunderTryingToVote() external {
        vm.warp(block.timestamp + 25000);
        stageRaise.openProjectForMilestoneVotes(1);

        address nonFunder = makeAddr("NON_FUNDER");
        vm.prank(nonFunder);
        vm.expectRevert(StageRaise__AddressHasNotFundTheProject.selector);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, true);
    }

    function testVotingOnClosedProject() external {
        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 1 ether}(1);

        vm.prank(TRYNAX);
        vm.expectRevert(StageRaise__ProjectIsNotOpenForMilestoneVotingProcess.selector);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, true);
    }

    function testCreateProjectWithZeroVotingTime() external {
        vm.expectRevert(StageRaise__VotingProcessFormilestoneMustBeInFuture.selector);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Test Project",
                description: "Test description",
                targetAmount: 5 ether,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 3,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 0,
                minFundingUSD: 1000e8, // $10
                maxFundingUSD: 10000e8 // $1000
            })
        );
    }

    function testFunderVotingTwice() external {
        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 1 ether}(1);

        vm.warp(block.timestamp + 25000);
        stageRaise.openProjectForMilestoneVotes(1);

        vm.startPrank(TRYNAX);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, true);

        vm.expectRevert(StageRaise__FunderHasAlreadyVoted.selector);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, false);
        vm.stopPrank();
    }

    function testFinalizeVotingTooEarly() external {
        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 1 ether}(1);

        vm.warp(block.timestamp + 25000);
        stageRaise.openProjectForMilestoneVotes(1);

        vm.expectRevert(StageRaise__TimeHasNotPassedForTheVotingProcess.selector);
        stageRaise.finalizeVotingProcess(1);
    }

    function testVotingAfterPeriodExpired() external {
        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 1 ether}(1);

        vm.warp(block.timestamp + 25000);
        stageRaise.openProjectForMilestoneVotes(1);

        vm.warp(block.timestamp + 300);

        vm.prank(TRYNAX);
        vm.expectRevert(StageRaise__VotingPeriodHasPassed.selector);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, true);
    }

    function testWithdrawWhileFundingActive() external {
        vm.startPrank(TRYNAX);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Active Project",
                description: "Still active for funding",
                targetAmount: 5 ether,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $10
                maxFundingUSD: 10000e8 // $1000
            })
        );

        stageRaise.fundProject{value: 2 ether}(6);

        vm.expectRevert(StageRaise__CannotWithdrawWhileFundingIsActive.selector);
        stageRaise.withdrawFunds(1 ether, 6, payable(TRYNAX));
        vm.stopPrank();
    }

    function testOpenVotingForFinalMilestone() external {
        vm.startPrank(TRYNAX);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Final Milestone Test",
                description: "Test final milestone",
                targetAmount: 5 ether,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 2,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $10
                maxFundingUSD: 10000e8 // $1000
            })
        );

        stageRaise.fundProject{value: 2 ether}(6);
        vm.warp(block.timestamp + 25000);

        stageRaise.openProjectForMilestoneVotes(6);
        stageRaise.takeAVoteForMilestoneStageIncrease(6, true);
        vm.warp(block.timestamp + 300);
        stageRaise.finalizeVotingProcess(6);

        vm.expectRevert(StageRaise__ProjectHasReachedTheFinalMileStoneStage.selector);
        stageRaise.openProjectForMilestoneVotes(6);
        vm.stopPrank();
    }

    function testOpenVotingForNonMilestoneProject() external {
        vm.startPrank(TRYNAX);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Non-Milestone Project",
                description: "No milestones",
                targetAmount: 5 ether,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $10
                maxFundingUSD: 10000e8 // $1000
            })
        );

        vm.warp(block.timestamp + 25000);

        vm.expectRevert(StageRaise__YouCannotOpenNonMilestoneProjectForVoting.selector);
        stageRaise.openProjectForMilestoneVotes(6);
        vm.stopPrank();
    }

    function testOpenVotingWhileFundingOngoing() external {
        vm.warp(block.timestamp + 15000);

        vm.expectRevert(StageRaise__YouCannotOpenProjectVotingWhileFundingIsOngoing.selector);
        stageRaise.openProjectForMilestoneVotes(1);
    }

    function testWithdrawFromNonExistentProject() external {
        vm.expectRevert(StageRaise__ProjectNotFound.selector);
        stageRaise.withdrawFunds(1 ether, 999, payable(address(this)));
    }

    function testCalculateFunderVotingPowerForNonExistentProject() external {
        vm.expectRevert(StageRaise__ProjectNotFound.selector);
        stageRaise.calculateFunderVotingPower(TRYNAX, 999);
    }

    function testCalculateFunderVotingPowerForNonFunder() external {
        address nonFunder = makeAddr("NON_FUNDER");
        vm.expectRevert(StageRaise__AddressHasNotFundTheProject.selector);
        stageRaise.calculateFunderVotingPower(nonFunder, 1);
    }

    function testOpenProjectForVotingAfterThreeFailures() external {
        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 1 ether}(1);

        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < 3; i++) {
            currentTime += 25000;
            vm.warp(currentTime);
            stageRaise.openProjectForMilestoneVotes(1);

            vm.prank(TRYNAX);
            stageRaise.takeAVoteForMilestoneStageIncrease(1, false);

            currentTime += 3000;
            vm.warp(currentTime);
            stageRaise.finalizeVotingProcess(1);
        }

        vm.warp(block.timestamp + 25000);
        vm.expectRevert(StageRaise__ProjectHasFailedTooManyMilestones.selector);
        stageRaise.openProjectForMilestoneVotes(1);
    }

    function testRequestRefundOnNonMilestoneProject() external {
        vm.startPrank(TRYNAX);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Non-Milestone Project",
                description: "No milestones",
                targetAmount: 5 ether,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8,
                maxFundingUSD: 10000e8
            })
        );

        stageRaise.fundProject{value: 1 ether}(6);

        vm.expectRevert(StageRaise__RefundIsNotAllowed.selector);
        stageRaise.requestRefund(6);
        vm.stopPrank();
    }

    function testRequestRefundByNonFunder() external {
        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 1 ether}(1);

        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < 3; i++) {
            currentTime += 25000;
            vm.warp(currentTime);
            stageRaise.openProjectForMilestoneVotes(1);

            vm.prank(TRYNAX);
            stageRaise.takeAVoteForMilestoneStageIncrease(1, false);

            currentTime += 300;
            vm.warp(currentTime);
            stageRaise.finalizeVotingProcess(1);
        }

        address nonFunder = makeAddr("NON_FUNDER");
        vm.prank(nonFunder);
        vm.expectRevert(StageRaise__AddressHasNotFundTheProject.selector);
        stageRaise.requestRefund(1);
    }

    function testRequestRefundBeforeThreeFailures() external {
        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 1 ether}(1);

        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < 2; i++) {
            currentTime += 25000;
            vm.warp(currentTime);
            stageRaise.openProjectForMilestoneVotes(1);

            vm.prank(TRYNAX);
            stageRaise.takeAVoteForMilestoneStageIncrease(1, false);

            currentTime += 300;
            vm.warp(currentTime);
            stageRaise.finalizeVotingProcess(1);
        }

        vm.prank(TRYNAX);
        vm.expectRevert(StageRaise__RefundIsNotAllowed.selector);
        stageRaise.requestRefund(1);
    }

    function testFinalizeVotingWhenNotOpen() external {
        vm.expectRevert(StageRaise__ProjectIsNotOpenForMilestoneVotingProcess.selector);
        stageRaise.finalizeVotingProcess(1);
    }

    // Testing Events

    function testProjectCreatedEvents() external {
        vm.warp(2000);
        uint256 deadline = 4000;

        vm.expectEmit(true, true, true, false);
        emit ProjectCreated("Credula", 10 ether, uint64(deadline));
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Credula",
                description: "decentralized crowdfunding",
                targetAmount: 10 ether,
                deadline: uint64(deadline),
                milestoneCount: 5,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFundingUSD: 1000e8, // $10
                maxFundingUSD: 10000e8 // $1000
            })
        );
    }

    function testProjectFundedEvents() external {
        vm.expectEmit(true, true, true, false);
        emit ProjectFunded("Stage Raise", 1 ether, address(TRYNAX));

        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 1 ether}(1);
    }

    function testWithdrawFundsEvents() external {
        stageRaise.fundProject{value: 5 ether}(1);
        vm.warp(block.timestamp + 2000000);
        vm.expectEmit(true, true, true, false);
        emit WithDrawnFromProject("Stage Raise", 1 ether, address(this));
        stageRaise.withdrawFunds(1 ether, 1, payable(TRYNAX));
    }

    function testProjectOpenedForVotingEvents() external {
        stageRaise.fundProject{value: 1 ether}(1);
        vm.warp(block.timestamp + 200000);
        vm.expectEmit(true, true, true, false);
        emit ProjectOpenedForVoting("Stage Raise", uint64(block.timestamp + 200), 1);
        stageRaise.openProjectForMilestoneVotes(1);
    }

    function testFinalizedProjectEvents() external {
        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 1 ether}(1);
        vm.warp(block.timestamp + 20000000);

        stageRaise.openProjectForMilestoneVotes(1);

        vm.startPrank(TRYNAX);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, true);
        vm.stopPrank();
        vm.warp(block.timestamp + 20000);
        vm.expectEmit(true, true, true, false);
        emit ProjectVotingProcessFinalized("Stage Raise", 1, true);
        stageRaise.finalizeVotingProcess(1);
    }

    function testRefundRequestedEvent() external {
        vm.prank(TRYNAX);
        stageRaise.fundProject{value: 1 ether}(1);

        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < 3; i++) {
            currentTime += 25000;
            vm.warp(currentTime);
            stageRaise.openProjectForMilestoneVotes(1);

            vm.prank(TRYNAX);
            stageRaise.takeAVoteForMilestoneStageIncrease(1, false);

            currentTime += 300;
            vm.warp(currentTime);
            stageRaise.finalizeVotingProcess(1);
        }

        vm.expectEmit(true, true, true, false);
        emit RefundRequested("Stage Raise", 1, TRYNAX, 1 ether);

        vm.prank(TRYNAX);
        stageRaise.requestRefund(1);
    }

    receive() external payable {}
}
