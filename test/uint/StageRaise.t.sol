// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StageRaise} from "../../src/StageRaise.sol";
import {console} from "forge-std/console.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

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
error StageRaise__TokenNotSupported();
error StageRaise__ProjectIsAlreadyOpenForMilestoneVotingProcess();

contract StageRaiseTest is Test {
    event ProjectCreated(string indexed name, uint96 indexed targetAmount, uint64 indexed deadline);
    event ProjectFunded(string indexed name, uint96 indexed AmoutFunded, address indexed Funder);
    event WithDrawnFromProject(string indexed name, uint96 indexed amountWithdrawn, address indexed Withdrawer);

    event ProjectOpenedForVoting(string indexed name, uint64 indexed timeOpenForVoting, uint32 indexed projectId);

    event ProjectVotingProcessFinalized(string indexed name, uint32 indexed projectById, bool indexed voteResult);

    event RefundRequested(
        string indexed projectName, uint32 indexed projectId, address indexed funder, uint96 refundAmount
    );

    StageRaise stageRaise;
    MockERC20 usdc;
    MockERC20 usdt;
    MockERC20 busd;
    
    address TRYNAX = payable(makeAddr("TRYNAX"));

    function setUp() public {
        HelperConfig helperConfig = new HelperConfig();
        (address usdcAddr, address usdtAddr, address busdAddr) = helperConfig.activeNetworkConfig();
        stageRaise = new StageRaise(usdcAddr, usdtAddr, busdAddr);
        
        usdc = MockERC20(usdcAddr);
        usdt = MockERC20(usdtAddr);
        busd = MockERC20(busdAddr);

        // Mint tokens to test users
        usdc.mint(address(this), 1_000_000e6); // 1M USDC
        usdc.mint(TRYNAX, 1_000_000e6);
        usdt.mint(address(this), 1_000_000e6); // 1M USDT
        usdt.mint(TRYNAX, 1_000_000e6);
        busd.mint(address(this), 1_000_000e18); // 1M BUSD
        busd.mint(TRYNAX, 1_000_000e18);

        // Approve stageRaise to spend tokens
        usdc.approve(address(stageRaise), type(uint256).max);
        usdt.approve(address(stageRaise), type(uint256).max);
        busd.approve(address(stageRaise), type(uint256).max);

        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Stage Raise",
                description: "decentralized crowdfunding",
                targetAmount: 10_000e18, // 10k in 18 decimals
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 5,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18, // $1000 in 18 decimals
                maxFunding: 50000e18, // $50000 in 18 decimals
                paymentToken: address(usdc)
            })
        );
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Stage Raise 2",
                description: "decentralized crowdfunding 2",
                targetAmount: 3000e18, // 3k in 18 decimals
                deadline: uint64(block.timestamp + 30000),
                milestoneCount: 5,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18, // $1000 in 18 decimals
                maxFunding: 50000e18, // $50000 in 18 decimals
                paymentToken: address(usdc)
            })
        );
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Stage Raise 3",
                description: "decentralized crowdfunding 3",
                targetAmount: 2000e18, // 2k in 18 decimals
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 5,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18, // $1000 in 18 decimals
                maxFunding: 50000e18, // $50000 in 18 decimals
                paymentToken: address(usdc)
            })
        );

        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Stage Raise 4",
                description: "decentralized crowdfunding 4",
                targetAmount: 3000e18,
                deadline: uint64(block.timestamp + 30000),
                milestoneCount: 5,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18,
                maxFunding: 50000e18,
                paymentToken: address(usdc)
            })
        );
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Stage Raise 5",
                description: "decentralized crowdfunding 5",
                targetAmount: 3000e18,
                deadline: uint64(block.timestamp + 30000),
                milestoneCount: 5,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18,
                maxFunding: 50000e18,
                paymentToken: address(usdc)
            })
        );
    }

    // Testing fuctions

    function testCreateProject() external {
        string memory name = stageRaise.getProjectBasicInfo(1).name;

        assert(keccak256(bytes(name)) == keccak256(bytes("Stage Raise")));
    }

    function testFundProject() external {
        // Fund with 1000 USDC (6 decimals)
        stageRaise.fundProject(1, 1000e6);

        uint256 raisedAmount = stageRaise.getProjectBasicInfo(1).raisedAmount;
        console.log("Raised amount (normalized):", raisedAmount);

        // Should be normalized to 18 decimals: 1000e18
        assert(raisedAmount == 1000e18);
        assert(usdc.balanceOf(address(stageRaise)) == 1000e6);
    }

    function testWithdrawFunds() external {
        vm.startPrank(TRYNAX);
        // Approve tokens for TRYNAX's usage
        vm.stopPrank();
        
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Stage Raise 6",
                description: "decentralized crowdfunding 6",
                targetAmount: 2000e18, // 2k in 18 decimals
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18,
                maxFunding: 50000e18,
                paymentToken: address(usdc)
            })
        );
        stageRaise.fundProject(6, 1000e6); // Fund with 1000 USDC
        vm.warp(block.timestamp + 2000000);
        stageRaise.withdrawFunds(1000e6, 6, payable(TRYNAX)); // Withdraw 1000 USDC (not normalized)
        vm.stopPrank();

        assert(stageRaise.getProjectBalance(6) == 0);
    }

    function testopeningProjectForVoting() external {
        vm.warp(block.timestamp + 200000);
        stageRaise.openProjectForMilestoneVotes(1);

        assert(stageRaise.getProjectMileStoneVotingStatus(1) == true);
    }

    function testForTakingAVote() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 1000e6); // Fund with 1000 USDC
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2000000);
        stageRaise.openProjectForMilestoneVotes(1);

        vm.startPrank(TRYNAX);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, true);
        vm.stopPrank();
        assert(stageRaise.getProjectYesVotes(1) == stageRaise.calculateFunderVotingPower(TRYNAX, 1));
        assert(stageRaise.getProjectNoVotes(1) == 0);
    }

    function testFinalizeVotingProcess() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 1000e6); // Fund with 1000 USDC
        vm.stopPrank();
        
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
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 1000e6); // Fund with 1000 USDC
        vm.stopPrank();

        vm.warp(block.timestamp + 25000);
        stageRaise.openProjectForMilestoneVotes(1);

        vm.prank(TRYNAX);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, false);

        assert(stageRaise.getProjectNoVotes(1) == stageRaise.calculateFunderVotingPower(TRYNAX, 1));
        assert(stageRaise.getProjectYesVotes(1) == 0);
    }

    function testRequestRefundAfterThreeFailures() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 2000e6); // Fund with 2000 USDC
        vm.stopPrank();

        vm.warp(block.timestamp + 25000);
        stageRaise.openProjectForMilestoneVotes(1);
        vm.prank(TRYNAX);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, true);
        vm.warp(block.timestamp + 300);
        stageRaise.finalizeVotingProcess(1);

        stageRaise.withdrawFunds(400e6, 1, payable(address(this))); // Withdraw 400 USDC

        for (uint256 i = 0; i < 3; i++) {
            vm.warp(block.timestamp + 25000);
            stageRaise.openProjectForMilestoneVotes(1);

            vm.prank(TRYNAX);
            stageRaise.takeAVoteForMilestoneStageIncrease(1, false);

            vm.warp(block.timestamp + 300);
            stageRaise.finalizeVotingProcess(1);
        }

        uint256 balanceBefore = usdc.balanceOf(TRYNAX);
        vm.prank(TRYNAX);
        stageRaise.requestRefund(1);
        uint256 balanceAfter = usdc.balanceOf(TRYNAX);

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

    function testGetProjectMinFunding() external {
        uint256 minFunding = stageRaise.getProjectMinFunding(1);
        assertEq(minFunding, 1000e18); // 18 decimals normalized
    }

    function testGetProjectMaxFunding() external {
        uint256 maxFunding = stageRaise.getProjectMaxFunding(1);
        assertEq(maxFunding, 50000e18); // 18 decimals normalized
    }

    function testGetAmountWithdrawableForNonMilestoneProject() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Non-Milestone Project",
                description: "No milestones",
                targetAmount: 5000e18, // 5k in 18 decimals
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18,
                maxFunding: 50000e18,
                paymentToken: address(usdc)
            })
        );

        stageRaise.fundProject(6, 3000e6); // Fund with 3000 USDC
        vm.stopPrank();

        uint256 withdrawable = stageRaise.getAmountWithdrawableForAProject(6);
        assert(withdrawable == 3000e6); // Returns denormalized amount
    }

    function testGetAmountWithdrawableForMilestoneProject() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 4000e6); // Fund with 4000 USDC
        vm.stopPrank();

        uint256 withdrawable = stageRaise.getAmountWithdrawableForAProject(1);
        // 20% of 4000 USDC = 800 USDC = 800e6
        assert(withdrawable == 800e6);
    }

    function testGetProjectAmountWithdrawn() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Withdrawal Test",
                description: "Test amount withdrawn",
                targetAmount: 5000e18, // 5k in 18 decimals
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18,
                maxFunding: 50000e18,
                paymentToken: address(usdc)
            })
        );

        stageRaise.fundProject(6, 3000e6); // Fund with 3000 USDC
        vm.warp(block.timestamp + 25000);
        stageRaise.withdrawFunds(1000e6, 6, payable(TRYNAX)); // Withdraw 1000 USDC
        vm.stopPrank();

        uint256 amountWithdrawn = stageRaise.getProjectAmountWithdrawn(6);
        assert(amountWithdrawn == 1000e18); // Stored normalized (18 decimals)
    }

    function testGetProjectFailedMilestoneStage() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 1000e6); // Fund with 1000 USDC
        vm.stopPrank();

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
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 2000e6); // Fund with 2000 USDC
        vm.stopPrank();

        uint256 contributorAmount = stageRaise.getProjectContributorAmount(1, TRYNAX);
        assert(contributorAmount == 2000e18); // Stored normalized

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
                targetAmount: 2000e18,
                deadline: uint64(block.timestamp),
                milestoneCount: 5,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18,
                maxFunding: 50000e18,
                paymentToken: address(usdc)
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
                minFunding: 1000e18,
                maxFunding: 50000e18,
                paymentToken: address(usdc)
            })
        );
    }

    function testFundProjectWithZero() external {
        vm.expectRevert(StageRaise__AmountToFundMustBeGreaterThanZero.selector);
        stageRaise.fundProject(1, 0);
    }

    function testFundingNonExistingProject() external {
        vm.expectRevert(StageRaise__ProjectNotFound.selector);
        stageRaise.fundProject(100, 2000e6);
    }

    function testFundingProjectWithAmountAboveMaxUSD() external {
        vm.expectRevert(StageRaise__FundingAmountAboveMaximum.selector);

        stageRaise.fundProject(1, 100000e6); // 100k USDC (above max of 50k)
    }

    function testFundingProjectWithAmountBelowMinUSD() external {
        vm.expectRevert(StageRaise__FundingAmountBelowMinimum.selector);
        stageRaise.fundProject(1, 1e6); // 1 USDC (below min of 1000)
    }

    function testFundingProjectWithAmountGreaterThanTarget() external {
        vm.expectRevert(StageRaise__TotalRaiseCantSurpassTargetRaise.selector);

        stageRaise.fundProject(3, 3000e6); // Fund 3000 USDC when target is 2000
    }

    function testFundingProjectThatDeadlineHasPassed() external {
        vm.warp(block.timestamp + 20002);
        vm.expectRevert(StageRaise__DeadlineForFundingHasPassed.selector);
        stageRaise.fundProject(1, 1000e6); // 1000 USDC
    }

    function testWithdrawingByNonOwner() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 5000e6); // 5000 USDC
        vm.warp(block.timestamp + 200000);
        vm.expectRevert(StageRaise__CanOnlyBeCalledByProjectOwner.selector);
        stageRaise.withdrawFunds(1000e6, 1, payable(TRYNAX)); // Try to withdraw 1000 USDC
        vm.stopPrank();
    }

    function testWithdrawingZeroAmount() external {
        stageRaise.fundProject(1, 5000e6); // 5000 USDC
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
                targetAmount: 10000e18,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 0,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18,
                maxFunding: 50000e18,
                paymentToken: address(usdc)
            })
        );
    }

    function testFundingInactiveProject() external {
        vm.warp(block.timestamp + 50000);
        vm.expectRevert(StageRaise__DeadlineForFundingHasPassed.selector);
        stageRaise.fundProject(1, 1000e6);
    }

    function testWithdrawMoreThanProjectBalance() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Test Project",
                description: "Test description",
                targetAmount: 5000e18,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18,
                maxFunding: 10000e18,
                paymentToken: address(usdc)
            })
        );

        stageRaise.fundProject(6, 2000e6); // Fund 2000 USDC
        vm.warp(block.timestamp + 25000);

        vm.expectRevert(StageRaise__YouCannotWithdrawMoreThanTheProjectBalance.selector);
        stageRaise.withdrawFunds(3000e6, 6, payable(TRYNAX)); // Try to withdraw 3000 USDC
        vm.stopPrank();
    }

    function testWithdrawMoreThanWithdrawableBalance() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Milestone Test",
                description: "Test milestone project",
                targetAmount: 5000e18,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 4,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18,
                maxFunding: 50000e18,
                paymentToken: address(usdc)
            })
        );

        stageRaise.fundProject(6, 4000e6); // Fund 4000 USDC
        vm.warp(block.timestamp + 25000);

        vm.expectRevert(StageRaise__YouCannotWithdrawMoreThanWithdrawableBalance.selector);
        stageRaise.withdrawFunds(2000e6, 6, payable(TRYNAX)); // Try to withdraw 2000 (20% is 800)
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
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 1000e6);
        vm.stopPrank();

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
                targetAmount: 5000e18,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 3,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 0,
                minFunding: 1000e18,
                maxFunding: 10000e18,
                paymentToken: address(usdc)
            })
        );
    }

    function testFunderVotingTwice() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 1000e6);
        vm.stopPrank();

        vm.warp(block.timestamp + 25000);
        stageRaise.openProjectForMilestoneVotes(1);

        vm.startPrank(TRYNAX);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, true);

        vm.expectRevert(StageRaise__FunderHasAlreadyVoted.selector);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, false);
        vm.stopPrank();
    }

    function testFinalizeVotingTooEarly() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 1000e6);
        vm.stopPrank();

        vm.warp(block.timestamp + 25000);
        stageRaise.openProjectForMilestoneVotes(1);

        vm.expectRevert(StageRaise__TimeHasNotPassedForTheVotingProcess.selector);
        stageRaise.finalizeVotingProcess(1);
    }

    function testVotingAfterPeriodExpired() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 1000e6);
        vm.stopPrank();

        vm.warp(block.timestamp + 25000);
        stageRaise.openProjectForMilestoneVotes(1);

        vm.warp(block.timestamp + 300);

        vm.prank(TRYNAX);
        vm.expectRevert(StageRaise__VotingPeriodHasPassed.selector);
        stageRaise.takeAVoteForMilestoneStageIncrease(1, true);
    }

    function testWithdrawWhileFundingActive() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Active Project",
                description: "Still active for funding",
                targetAmount: 5000e18,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18,
                maxFunding: 10000e18,
                paymentToken: address(usdc)
            })
        );

        stageRaise.fundProject(6, 2000e6);

        vm.expectRevert(StageRaise__CannotWithdrawWhileFundingIsActive.selector);
        stageRaise.withdrawFunds(1000e6, 6, payable(TRYNAX));
        vm.stopPrank();
    }

    function testOpenVotingForFinalMilestone() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Final Milestone Test",
                description: "Test final milestone",
                targetAmount: 5000e18,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 2,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18,
                maxFunding: 10000e18,
                paymentToken: address(usdc)
            })
        );

        stageRaise.fundProject(6, 2000e6);
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
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Non-Milestone Project",
                description: "No milestones",
                targetAmount: 5000e18,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18,
                maxFunding: 10000e18,
                paymentToken: address(usdc)
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

    function testOpenVotingWhileAlreadyOpen() external {
        vm.warp(block.timestamp + 25000);
        stageRaise.openProjectForMilestoneVotes(1);

        vm.expectRevert(StageRaise__ProjectIsAlreadyOpenForMilestoneVotingProcess.selector);
        stageRaise.openProjectForMilestoneVotes(1);
    }

    function testWithdrawFromNonExistentProject() external {
        vm.expectRevert(StageRaise__ProjectNotFound.selector);
        stageRaise.withdrawFunds(1000e6, 999, payable(address(this)));
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
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 1000e6);
        vm.stopPrank();

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
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Non-Milestone Project",
                description: "No milestones",
                targetAmount: 5000e18,
                deadline: uint64(block.timestamp + 20000),
                milestoneCount: 0,
                milestoneBased: false,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18,
                maxFunding: 10000e18,
                paymentToken: address(usdc)
            })
        );

        stageRaise.fundProject(6, 1000e6);

        vm.expectRevert(StageRaise__RefundIsNotAllowed.selector);
        stageRaise.requestRefund(6);
        vm.stopPrank();
    }

    function testRequestRefundByNonFunder() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 1000e6);
        vm.stopPrank();

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
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 1000e6);
        vm.stopPrank();

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

    function testFinalizeVotingResetsVotingEndTime() external {
        vm.warp(block.timestamp + 25000);
        stageRaise.openProjectForMilestoneVotes(1);

        uint64 votingEndTime = stageRaise.getProjectVotingEndTime(1);
        assertTrue(votingEndTime > 0);

        vm.warp(votingEndTime + 1);
        stageRaise.finalizeVotingProcess(1);

        assertEq(stageRaise.getProjectVotingEndTime(1), 0);
        assertEq(stageRaise.getCurrentVotingRound(1), 2);
        assertFalse(stageRaise.getProjectMileStoneVotingStatus(1));
    }

    // Testing Events

    function testProjectCreatedEvents() external {
        vm.warp(2000);
        uint256 deadline = 4000;

        uint256 projectCountBefore = stageRaise.getProjectCount();
        
        stageRaise.createProject(
            StageRaise.CreateProjectParams({
                name: "Credula",
                description: "decentralized crowdfunding",
                targetAmount: 10000e18,
                deadline: uint64(deadline),
                milestoneCount: 5,
                milestoneBased: true,
                timeForMileStoneVotingProcess: 200,
                minFunding: 1000e18,
                maxFunding: 10000e18,
                paymentToken: address(usdc)
            })
        );
        
        uint256 projectCountAfter = stageRaise.getProjectCount();
        assertEq(projectCountAfter, projectCountBefore + 1);
    }

    function testProjectFundedEvents() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        
        vm.expectEmit(true, true, true, false);
        emit ProjectFunded("Stage Raise", 1000e18, address(TRYNAX)); // Normalized to 18 decimals
        stageRaise.fundProject(1, 1000e6); // Fund with 1000 USDC
        vm.stopPrank();
    }

    function testWithdrawFundsEvents() external {
        stageRaise.fundProject(1, 5000e6); // Fund with 5000 USDC
        vm.warp(block.timestamp + 2000000);
        vm.expectEmit(true, true, true, false);
        emit WithDrawnFromProject("Stage Raise", 1000e6, address(this)); // Denormalized USDC amount
        stageRaise.withdrawFunds(1000e6, 1, payable(TRYNAX)); // Withdraw 1000 USDC
    }

    function testProjectOpenedForVotingEvents() external {
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 1000e6);
        vm.warp(block.timestamp + 200000);
        vm.expectEmit(true, true, true, false);
        emit ProjectOpenedForVoting("Stage Raise", uint64(block.timestamp + 200), 1);
        stageRaise.openProjectForMilestoneVotes(1);
    }

    function testFinalizedProjectEvents() external {
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 1000e6);
        vm.stopPrank();
        
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
        vm.startPrank(TRYNAX);
        usdc.approve(address(stageRaise), type(uint256).max);
        stageRaise.fundProject(1, 1000e6); // Fund with 1000 USDC
        vm.stopPrank();

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
        emit RefundRequested("Stage Raise", 1, TRYNAX, 1000e18); // Normalized amount

        vm.prank(TRYNAX);
        stageRaise.requestRefund(1);
    }

    receive() external payable {}
}
