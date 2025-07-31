// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions
// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

//Error

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
error StageRaise__FundingAmountBelowMinimum();
error StageRaise__FundingAmountAboveMaximum();
error StageRaise__MinFundingMustBeLessThanMaxFunding();
error StageRaise__RefundIsNotAllowed();
error StageRaise__ProjectHasFailedTooManyMilestones();

contract StageRaise {
    //Types

    struct ProjectBasics {
        address owner; //20 bytes
        uint88 targetAmount; // 11 bytes
        bool isActive; // 1 byte
        // 32 bytes
        uint88 raisedAmount; // 11 bytes
        uint64 deadline; // 8 bytes
        uint24 totalContributors; // 3 bytes
        uint32 projectId; // 4 bytes
        // 26 bytes
        uint96 minFundingUSD; //12 bytes Minimum funding amount in USD (8 decimals)
        uint96 maxFundingUSD; //12 bytes Maximum funding amount in USD (8 decimals)
        //24 bytes
        string name;
        string description;
    }

    struct ProjectMilestone {
        uint8 milestoneCount; // 1 bytes
        bool milestoneBased; // 1 byte
        uint8 milestoneStage; // 1 byte
        bool openForMilestoneVotingStage; // 1 byte
        uint8 failedMilestoneStage; // 1 bytes
        uint88 votesForYes; // 11 bytes
        uint64 timeForMilestoneVotingProcess;    // 8 bytes
        uint64 timeForTheVotingProcessToElapsed; // 8 bytes
        // 32 bytes
        
        uint88 votesForNo; // 11 bytes
        


        
    }

    struct Project {
        ProjectBasics basics; // 5 slots
        ProjectMilestone milestone; // 2 slots
        uint88 projectBalance;
        // 11 bytes
        uint88 amountWithdrawn;
        // 11 bytes
        mapping(address => uint128) contributorsToAmountFunded;
        mapping(address => bool) hasFunderVoted;
        address[] voters;
    }

    struct ProjectInfo {
        address owner; // 20 bytes
        uint88 targetAmount; //11 bytes
        bool isActive; // 1 byte
        // 32 bytes
        uint88 raisedAmount; // 11 bytes
        uint64 deadline; // 8 bytes
        bool milestoneBased; // 1 byte
        uint96 minFundingUSD; // 12 bytes USD (8 decimals)
        // 32 bytes 
        uint24 totalContributors; // 3 bytes
        uint96 maxFundingUSD; // 12 bytes USD (8 decimals)
        uint8 milestoneCount; // 1 byte
        // 16 bytes
        string name;
        string description;
    }

    struct CreateProjectParams {
        uint88 targetAmount; // 11 bytes
        uint64 deadline; // 8 bytes
        uint8 milestoneCount; // 1 byte
        bool milestoneBased; // 1 byte
        uint64 timeForMileStoneVotingProcess; // 8 bytes
        uint96 minFundingUSD; // 12 bytes USD (8 decimals)
        uint96 maxFundingUSD; // 12 bytes USD (8 decimals)
        string name;
        string description;
    }

    //State Variables
    mapping(uint32 => Project) public projectById;
    uint32 private s_projectCount;
    AggregatorV3Interface public s_aggregator;

    //Events

    event ProjectCreated(string indexed name, uint88 indexed targetAmount, uint64 indexed deadline);
    event ProjectFunded(string indexed name, uint88 indexed amountFunded, address indexed funder);

    event WithDrawnFromProject(string indexed name, uint88 indexed amountWithdrawn, address indexed Withdrawer);

    event ProjectOpenedForVoting(string indexed name, uint64 indexed timeOpenForVoting, uint32 indexed projectId);

    event ProjectVotingProcessFinalized(string indexed name, uint32 indexed projectById, bool indexed voteResult);

    event RefundRequested(
        string indexed projectName, uint32 indexed projectId, address indexed funder, uint88 refundAmount
    );
    //Modifier

    modifier onlyProjectOwner(uint32 _projectId) {
        if (projectById[_projectId].basics.owner == address(0)) {
            revert StageRaise__ProjectNotFound();
        }

        if (projectById[_projectId].basics.owner != msg.sender) {
            revert StageRaise__CanOnlyBeCalledByProjectOwner();
        }
        _;
    }

    modifier onlyProjectFunder(uint32 _projectId) {
        if (projectById[_projectId].contributorsToAmountFunded[msg.sender] == 0) {
            revert StageRaise__AddressHasNotFundTheProject();
        }

        _;
    }

    constructor(address _aggregatorAddress) {
        s_aggregator = AggregatorV3Interface(_aggregatorAddress);
    }

    //Functions

    function createProject(CreateProjectParams memory params) external {
        if (block.timestamp >= params.deadline) {
            revert StageRaise__DeadlineMustBeInFuture();
        }
        if (params.targetAmount <= 0) {
            revert StageRaise__TargetAmountMustBeGreaterThanZero();
        }

        if (params.milestoneBased != false && params.milestoneCount <= 0) {
            revert StageRaise__YouCannotHaveZeroMilestoneForAMileStoneProject();
        }

        if (params.timeForMileStoneVotingProcess <= 0) {
            revert StageRaise__VotingProcessFormilestoneMustBeInFuture();
        }

        if (params.minFundingUSD >= params.maxFundingUSD) {
            revert StageRaise__MinFundingMustBeLessThanMaxFunding();
        }

        s_projectCount++;

        Project storage newProject = projectById[s_projectCount];

        // Set basic project info
        newProject.basics.name = params.name;
        newProject.basics.owner = msg.sender;
        newProject.basics.projectId = s_projectCount;
        newProject.basics.description = params.description;
        newProject.basics.targetAmount = params.targetAmount;
        newProject.basics.raisedAmount = 0;
        newProject.basics.deadline = params.deadline;
        newProject.basics.isActive = true;
        newProject.basics.totalContributors = 0;
        newProject.basics.minFundingUSD = params.minFundingUSD;
        newProject.basics.maxFundingUSD = params.maxFundingUSD;

        // Set milestone info
        newProject.milestone.milestoneCount = params.milestoneCount;
        newProject.milestone.milestoneBased = params.milestoneBased;
        newProject.milestone.timeForMilestoneVotingProcess = params.timeForMileStoneVotingProcess;
        if (params.milestoneBased == true) {
            newProject.milestone.milestoneStage = 1;
        }

        // Set financial info
        newProject.projectBalance = 0;
        newProject.amountWithdrawn = 0;

        emit ProjectCreated(params.name, params.targetAmount, params.deadline);
    }

    function fundProject(uint32 _projectId) external payable {
        if (msg.value <= 0) {
            revert StageRaise__AmountToFundMustBeGreaterThanZero();
        }
        if (projectById[_projectId].basics.owner == address(0)) {
            revert StageRaise__ProjectNotFound();
        }
        if (!projectById[_projectId].basics.isActive) {
            revert StageRaise__ProjectNotActive();
        }

        uint256 fundingAmountUSD = getUSDValue(msg.value);
        if (fundingAmountUSD < projectById[_projectId].basics.minFundingUSD) {
            revert StageRaise__FundingAmountBelowMinimum();
        }

        uint256 funderCurrentContribution = getUSDValue(projectById[_projectId].contributorsToAmountFunded[msg.sender]);
        if ((fundingAmountUSD + funderCurrentContribution) > projectById[_projectId].basics.maxFundingUSD) {
            revert StageRaise__FundingAmountAboveMaximum();
        }

        if (msg.value + projectById[_projectId].basics.raisedAmount > projectById[_projectId].basics.targetAmount) {
            revert StageRaise__TotalRaiseCantSurpassTargetRaise();
        }
        if (block.timestamp > projectById[_projectId].basics.deadline) {
            projectById[_projectId].basics.isActive = false;
            revert StageRaise__DeadlineForFundingHasPassed();
        }
        Project storage project = projectById[_projectId];
        if (project.contributorsToAmountFunded[msg.sender] == 0) {
            project.basics.totalContributors++;
        }
        project.basics.raisedAmount += uint88(msg.value);
        project.projectBalance += uint88(msg.value);
        project.contributorsToAmountFunded[msg.sender] += uint128(msg.value);

        emit ProjectFunded(project.basics.name, uint88(msg.value), msg.sender);
    }

    function openProjectForMilestoneVotes(uint32 _projectId) external onlyProjectOwner(_projectId) {
        Project storage project = projectById[_projectId];

        if (!project.milestone.milestoneBased) {
            revert StageRaise__YouCannotOpenNonMilestoneProjectForVoting();
        }

        if (project.milestone.failedMilestoneStage >= 3) {
            revert StageRaise__ProjectHasFailedTooManyMilestones();
        }

        if (project.milestone.milestoneStage >= project.milestone.milestoneCount) {
            revert StageRaise__ProjectHasReachedTheFinalMileStoneStage();
        }
        if (project.basics.deadline >= block.timestamp) {
            revert StageRaise__YouCannotOpenProjectVotingWhileFundingIsOngoing();
        }
        project.milestone.openForMilestoneVotingStage = true;
        project.milestone.timeForTheVotingProcessToElapsed =
            project.milestone.timeForMilestoneVotingProcess + uint64(block.timestamp);
        emit ProjectOpenedForVoting(project.basics.name, project.milestone.timeForTheVotingProcessToElapsed, _projectId);
    }

    function finalizeVotingProcess(uint32 _projectId) external {
        Project storage project = projectById[_projectId];
        if (!(block.timestamp >= project.milestone.timeForTheVotingProcessToElapsed)) {
            revert StageRaise__TimeHasNotPassedForTheVotingProcess();
        }
        if (!project.milestone.openForMilestoneVotingStage) {
            revert StageRaise__ProjectIsNotOpenForMilestoneVotingProcess();
        }

        if (project.milestone.votesForYes > project.milestone.votesForNo) {
            project.milestone.milestoneStage++;
            project.milestone.failedMilestoneStage = 0;
        } else {
            project.milestone.failedMilestoneStage++;
        }
        bool voteResult = project.milestone.votesForYes > project.milestone.votesForNo ? true : false;
        project.milestone.votesForNo = 0;
        project.milestone.votesForYes = 0;
        resetVotersMapping(_projectId);
        project.milestone.openForMilestoneVotingStage = false;
        emit ProjectVotingProcessFinalized(project.basics.name, _projectId, voteResult);
    }

    function withdrawFunds(uint88 _amount, uint32 _projectId, address payable _to)
        external
        onlyProjectOwner(_projectId)
    {
        if (_amount <= 0) {
            revert StageRaise__AmountToWithdrawMustBeGreaterThanZero();
        }
        if (projectById[_projectId].projectBalance < _amount) {
            revert StageRaise__YouCannotWithdrawMoreThanTheProjectBalance();
        }
        if (_amount > getAmountWithdrawableForAProject(_projectId)) {
            revert StageRaise__YouCannotWithdrawMoreThanWithdrawableBalance();
        }

        if (block.timestamp <= projectById[_projectId].basics.deadline) {
            revert StageRaise__CannotWithdrawWhileFundingIsActive();
        }

        projectById[_projectId].projectBalance -= _amount;
        projectById[_projectId].amountWithdrawn += _amount;
        (bool success,) = _to.call{value: _amount}("");

        if (!success) {
            revert StageRaise__ETHTransferFailed();
        }

        emit WithDrawnFromProject(projectById[_projectId].basics.name, _amount, msg.sender);
    }

    function takeAVoteForMilestoneStageIncrease(uint32 _projectId, bool _vote)
        external
        onlyProjectFunder(_projectId)
    {
        Project storage project = projectById[_projectId];

        if (project.hasFunderVoted[msg.sender]) {
            revert StageRaise__FunderHasAlreadyVoted();
        }

        if (!project.milestone.openForMilestoneVotingStage) {
            revert StageRaise__ProjectIsNotOpenForMilestoneVotingProcess();
        }
        if (block.timestamp > project.milestone.timeForTheVotingProcessToElapsed) {
            revert StageRaise__VotingPeriodHasPassed();
        }
        if (_vote == true) {
            project.milestone.votesForYes += calculateFunderVotingPower(msg.sender, _projectId);
        } else {
            project.milestone.votesForNo += calculateFunderVotingPower(msg.sender, _projectId);
        }
        project.voters.push(msg.sender);
        project.hasFunderVoted[msg.sender] = true;
    }

    function resetVotersMapping(uint32 _projectId) private {
        Project storage project = projectById[_projectId];

        for (uint256 i = 0; i < project.voters.length; i++) {
            project.hasFunderVoted[project.voters[i]] = false;
        }

        delete project.voters;
    }

    function requestRefund(uint32 _projectId) external onlyProjectFunder(_projectId) {
        Project storage project = projectById[_projectId];

        if (project.basics.owner == address(0)) {
            revert StageRaise__ProjectNotFound();
        }
        if (!project.milestone.milestoneBased) {
            revert StageRaise__RefundIsNotAllowed();
        }

        if (project.milestone.failedMilestoneStage < 3) {
            revert StageRaise__RefundIsNotAllowed();
        }

        uint128 funderContribution = project.contributorsToAmountFunded[msg.sender];

        if (funderContribution == 0) {
            revert StageRaise__AmountToWithdrawMustBeGreaterThanZero();
        }

        uint256 remainingFundsForRefund = project.basics.raisedAmount - project.amountWithdrawn;
        uint88 amountToRefund = uint88((funderContribution * remainingFundsForRefund) / project.basics.raisedAmount);

        if (amountToRefund <= 0) {
            revert StageRaise__AmountToWithdrawMustBeGreaterThanZero();
        }

        project.contributorsToAmountFunded[msg.sender] = 0;
        project.projectBalance -= amountToRefund;

        (bool success,) = payable(msg.sender).call{value: amountToRefund}("");
        if (!success) {
            revert StageRaise__ETHTransferFailed();
        }

        emit RefundRequested(project.basics.name, _projectId, msg.sender, amountToRefund);
    }

    // view & pure functions

    function getProjectBasicInfo(uint32 _projectId) public view returns (ProjectInfo memory) {
        Project storage p = projectById[_projectId];

        return ProjectInfo({
            owner: p.basics.owner,
            name: p.basics.name,
            description: p.basics.description,
            targetAmount: p.basics.targetAmount,
            raisedAmount: p.basics.raisedAmount,
            deadline: p.basics.deadline,
            isActive: p.basics.isActive,
            totalContributors: p.basics.totalContributors,
            minFundingUSD: p.basics.minFundingUSD,
            maxFundingUSD: p.basics.maxFundingUSD,
            milestoneCount: p.milestone.milestoneCount,
            milestoneBased: p.milestone.milestoneBased
        });
    }

    function getAmountWithdrawableForAProject(uint32 _projectId) public view returns (uint88) {
        Project storage project = projectById[_projectId];
        if (project.basics.owner == address(0)) {
            return 0;
        }

        if (!project.milestone.milestoneBased) {
            return project.projectBalance;
        }

        uint256 maxWithdrawable =
            (project.basics.raisedAmount * project.milestone.milestoneStage) / project.milestone.milestoneCount;
        uint88 maxWithdrawableNow = uint88(maxWithdrawable - project.amountWithdrawn);
        return maxWithdrawableNow;
    }

    function calculateFunderVotingPower(address _funder, uint32 _projectId)
        public
        view
        returns (uint88 votingPower)
    {
        Project storage project = projectById[_projectId];

        if (project.basics.owner == address(0)) {
            revert StageRaise__ProjectNotFound();
        }
        if (project.contributorsToAmountFunded[_funder] == 0) {
            revert StageRaise__AddressHasNotFundTheProject();
        }

        uint128 amountFundedByTheFunder = project.contributorsToAmountFunded[_funder];

        votingPower = uint88((amountFundedByTheFunder * 1e18) / project.basics.raisedAmount);

        return votingPower;
    }

    function getProjectCount() public view returns (uint32) {
        return s_projectCount;
    }

    function getProjectBalance(uint32 _projectId) public view returns (uint88) {
        return projectById[_projectId].projectBalance;
    }

    function getProjectAmountWithdrawn(uint32 _projectId) public view returns (uint88) {
        return projectById[_projectId].amountWithdrawn;
    }

    function getProjectMilestoneStage(uint32 _projectId) public view returns (uint8) {
        return projectById[_projectId].milestone.milestoneStage;
    }

    function getProjectMileStoneVotingStatus(uint32 _projectId) public view returns (bool) {
        return projectById[_projectId].milestone.openForMilestoneVotingStage;
    }

    function getProjectYesVotes(uint32 _projectId) public view returns (uint88) {
        return projectById[_projectId].milestone.votesForYes;
    }

    function getProjectNoVotes(uint32 _projectId) public view returns (uint88) {
        return projectById[_projectId].milestone.votesForNo;
    }

    function getEthPrice() public view returns (uint256) {
        (, int256 price,,,) = s_aggregator.latestRoundData();

        return uint256(price);
    }

    function getAggregatorDecimals() public view returns (uint8) {
        return s_aggregator.decimals();
    }

    function getUSDValue(uint256 _ethAmount) public view returns (uint256) {
        (, int256 price,,,) = s_aggregator.latestRoundData();

        return (uint256(price) * _ethAmount) / 1e18;
    }

    function getETHValue(uint256 _usdAmount) public view returns (uint256) {
        (, int256 price,,,) = s_aggregator.latestRoundData();

        return (_usdAmount * 1e18) / uint256(price);
    }

    function getProjectMinFundingUSD(uint32 _projectId) public view returns (uint96) {
        return projectById[_projectId].basics.minFundingUSD;
    }

    function getProjectMaxFundingUSD(uint32 _projectId) public view returns (uint96) {
        return projectById[_projectId].basics.maxFundingUSD;
    }

    function getProjectFailedMilestoneStage(uint32 _projectId) public view returns (uint8) {
        return projectById[_projectId].milestone.failedMilestoneStage;
    }

    function getProjectContributorAmount(uint32 _projectId, address _contributor) public view returns (uint128) {
        return projectById[_projectId].contributorsToAmountFunded[_contributor];
    }

    function getProjectVotingEndTime(uint32 _projectId) public view returns (uint64) {
        return projectById[_projectId].milestone.timeForTheVotingProcessToElapsed;
    }
}
