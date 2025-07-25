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
        address owner;
        uint256 projectId;
        string name;
        string description;
        uint256 targetAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        uint256 totalContributors;
        uint256 minFundingUSD; // Minimum funding amount in USD (8 decimals)
        uint256 maxFundingUSD; // Maximum funding amount in USD (8 decimals)
    }

    struct ProjectMilestone {
        uint256 milestoneCount;
        bool milestoneBased;
        uint256 milestoneStage;
        bool openForMilestoneVotingStage;
        uint256 votesForYes;
        uint256 votesForNo;
        uint256 timeForMilestoneVotingProcess;
        uint256 timeForTheVotingProcessToElapsed;
        uint256 failedMilestoneStage;
    }

    struct Project {
        ProjectBasics basics;
        ProjectMilestone milestone;
        uint256 projectBalance;
        uint256 amountWithdrawn;
        mapping(address => uint256) contributorsToAmountFunded;
        mapping(address => bool) hasFunderVoted;
        address[] voters;
    }

    struct ProjectInfo {
        address owner;
        string name;
        string description;
        uint256 targetAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        uint256 totalContributors;
        uint256 minFundingUSD;
        uint256 maxFundingUSD;
        uint256 milestoneCount;
        bool milestoneBased;
    }

    struct CreateProjectParams {
        string name;
        string description;
        uint256 targetAmount;
        uint256 deadline;
        uint256 milestoneCount;
        bool milestoneBased;
        uint256 timeForMileStoneVotingProcess;
        uint256 minFundingUSD; // USD (8 decimals)
        uint256 maxFundingUSD;
    }

    //State Variables
    mapping(uint256 => Project) public projectById;
    uint256 private s_projectCount;
    AggregatorV3Interface public s_aggregator;

    //Events

    event ProjectCreated(string indexed name, uint256 indexed targetAmount, uint256 indexed deadline);
    event ProjectFunded(string indexed name, uint256 indexed amountFunded, address indexed funder);

    event WithDrawnFromProject(string indexed name, uint256 indexed amountWithdrawn, address indexed Withdrawer);

    event ProjectOpenedForVoting(string indexed name, uint256 indexed timeOpenForVoting, uint256 indexed projectId);

    event ProjectVotingProcessFinalized(string indexed name, uint256 indexed projectById, bool indexed voteResult);

    event RefundRequested(
        string indexed projectName, uint256 indexed projectId, address indexed funder, uint256 refundAmount
    );
    //Modifier

    modifier onlyProjectOwner(uint256 _projectId) {
        if (projectById[_projectId].basics.owner == address(0)) {
            revert StageRaise__ProjectNotFound();
        }

        if (projectById[_projectId].basics.owner != msg.sender) {
            revert StageRaise__CanOnlyBeCalledByProjectOwner();
        }
        _;
    }

    modifier onlyProjectFunder(uint256 _projectId) {
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

    function fundProject(uint256 _projectId) external payable {
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
        project.basics.raisedAmount += msg.value;
        project.projectBalance += msg.value;
        project.contributorsToAmountFunded[msg.sender] += msg.value;

        emit ProjectFunded(project.basics.name, msg.value, msg.sender);
    }

    function openProjectForMilestoneVotes(uint256 _projectId) external onlyProjectOwner(_projectId) {
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
            project.milestone.timeForMilestoneVotingProcess + block.timestamp;
        emit ProjectOpenedForVoting(project.basics.name, project.milestone.timeForTheVotingProcessToElapsed, _projectId);
    }

    function finalizeVotingProcess(uint256 _projectId) external {
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

    function withdrawFunds(uint256 _amount, uint256 _projectId, address payable _to)
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

    function takeAVoteForMilestoneStageIncrease(uint256 _projectId, bool _vote)
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

    function resetVotersMapping(uint256 _projectId) private {
        Project storage project = projectById[_projectId];

        for (uint256 i = 0; i < project.voters.length; i++) {
            project.hasFunderVoted[project.voters[i]] = false;
        }

        delete project.voters;
    }

    function requestRefund(uint256 _projectId) external onlyProjectFunder(_projectId) {
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

        uint256 funderContribution = project.contributorsToAmountFunded[msg.sender];

        if (funderContribution == 0) {
            revert StageRaise__AmountToWithdrawMustBeGreaterThanZero();
        }

        uint256 remainingFundsForRefund = project.basics.raisedAmount - project.amountWithdrawn;
        uint256 amountToRefund = (funderContribution * remainingFundsForRefund) / project.basics.raisedAmount;

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

    function getProjectBasicInfo(uint256 _projectId) public view returns (ProjectInfo memory) {
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

    function getAmountWithdrawableForAProject(uint256 _projectId) public view returns (uint256) {
        Project storage project = projectById[_projectId];
        if (project.basics.owner == address(0)) {
            return 0;
        }

        if (!project.milestone.milestoneBased) {
            return project.projectBalance;
        }

        uint256 maxWithdrawable =
            (project.basics.raisedAmount * project.milestone.milestoneStage) / project.milestone.milestoneCount;
        uint256 maxWithdrawableNow = maxWithdrawable - project.amountWithdrawn;
        return maxWithdrawableNow;
    }

    function calculateFunderVotingPower(address _funder, uint256 _projectId)
        public
        view
        returns (uint256 votingPower)
    {
        Project storage project = projectById[_projectId];

        if (project.basics.owner == address(0)) {
            revert StageRaise__ProjectNotFound();
        }
        if (project.contributorsToAmountFunded[_funder] == 0) {
            revert StageRaise__AddressHasNotFundTheProject();
        }

        uint256 amountFundedByTheFunder = project.contributorsToAmountFunded[_funder];

        votingPower = (amountFundedByTheFunder * 1e18) / project.basics.raisedAmount;

        return votingPower;
    }

    function getProjectCount() public view returns (uint256) {
        return s_projectCount;
    }

    function getProjectBalance(uint256 _projectId) public view returns (uint256) {
        return projectById[_projectId].projectBalance;
    }

    function getProjectAmountWithdrawn(uint256 _projectId) public view returns (uint256) {
        return projectById[_projectId].amountWithdrawn;
    }

    function getProjectMilestoneStage(uint256 _projectId) public view returns (uint256) {
        return projectById[_projectId].milestone.milestoneStage;
    }

    function getProjectMileStoneVotingStatus(uint256 _projectId) public view returns (bool) {
        return projectById[_projectId].milestone.openForMilestoneVotingStage;
    }

    function getProjectYesVotes(uint256 _projectId) public view returns (uint256) {
        return projectById[_projectId].milestone.votesForYes;
    }

    function getProjectNoVotes(uint256 _projectId) public view returns (uint256) {
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

    function getProjectMinFundingUSD(uint256 _projectId) public view returns (uint256) {
        return projectById[_projectId].basics.minFundingUSD;
    }

    function getProjectMaxFundingUSD(uint256 _projectId) public view returns (uint256) {
        return projectById[_projectId].basics.maxFundingUSD;
    }

    function getProjectFailedMilestoneStage(uint256 _projectId) public view returns (uint256) {
        return projectById[_projectId].milestone.failedMilestoneStage;
    }

    function getProjectContributorAmount(uint256 _projectId, address _contributor) public view returns (uint256) {
        return projectById[_projectId].contributorsToAmountFunded[_contributor];
    }

    function getProjectVotingEndTime(uint256 _projectId) public view returns (uint256) {
        return projectById[_projectId].milestone.timeForTheVotingProcessToElapsed;
    }
}
