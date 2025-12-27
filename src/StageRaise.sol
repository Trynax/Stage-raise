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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "forge-std/console.sol";

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
error StageRaise__TokenNotSupported();
error StageRaise__InvalidTokenAddress();

contract StageRaise is Ownable {
    using SafeERC20 for IERC20;
    //Types

    struct ProjectBasics {
        // Slot 0: 32 bytes
        address owner;              // 20 bytes
        uint64 deadline;            // 8 bytes
        uint32 projectId;           // 4 bytes
        // Slot 1: 32 bytes
        address paymentToken;       // 20 bytes
        uint96 minFunding;          // 12 bytes
        // Slot 2: 32 bytes  
        uint96 maxFunding;          // 12 bytes
        uint24 totalContributors;   // 3 bytes
        bool isActive;              // 1 byte
        // Slot 3: 32 bytes
        uint256 targetAmount;       // 32 bytes 
        // Slot 4: 32 bytes
        uint256 raisedAmount;       // 32 bytes 
        // Slots 5+: dynamic
        string name;
        string description;
    }

    struct ProjectMilestone {
        // Slot 0: 32 bytes
        uint64 timeForMilestoneVotingProcess;       // 8 bytes
        uint64 timeForTheVotingProcessToElapsed;    // 8 bytes
        uint8 milestoneCount;                       // 1 byte
        uint8 milestoneStage;                       // 1 byte
        uint8 failedMilestoneStage;                 // 1 byte
        uint8 votingRound;                          // 1 byte
        bool milestoneBased;                        // 1 byte
        bool openForMilestoneVotingStage;           // 1 byte
        // Slot 1: 32 bytes
        uint256 votesForYes;                        // 32 bytes
        // Slot 2: 32 bytes
        uint256 votesForNo;                         // 32 bytes
    }

    struct Project {
        ProjectBasics basics;           // 5+ slots (5 fixed + strings)
        ProjectMilestone milestone;     // 3 slots
        // Slot N: 24 bytes packed together
        uint96 projectBalance;          // 12 bytes
        uint96 amountWithdrawn;         // 12 bytes
        // Mappings (separate slots)
        mapping(address => uint128) contributorsToAmountFunded;
        mapping(address => uint8) funderVotingRound;
    }

    struct ProjectInfo {
        address owner;
        address paymentToken;
        uint256 targetAmount;          
        uint256 raisedAmount;          
        uint96 minFunding;             
        uint96 maxFunding;             
        uint64 deadline;
        uint32 projectId;
        uint24 totalContributors;
        uint8 milestoneCount;
        bool isActive;
        bool milestoneBased;
        string name;
        string description;
    }

    struct CreateProjectParams {
        address paymentToken;                   
        uint256 targetAmount;                  
        uint96 minFunding;                     
        uint96 maxFunding;                     
        uint64 deadline;
        uint64 timeForMileStoneVotingProcess;
        uint8 milestoneCount;
        bool milestoneBased;
        string name;
        string description;
    }

    mapping(uint32 => Project) public projectById;
    uint32 private s_projectCount;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint8) public tokenDecimals;

    //Events

    event ProjectCreated(string indexed name, uint256 indexed targetAmount, uint64 indexed deadline);
    event ProjectFunded(string indexed name, uint96 indexed amountFunded, address indexed funder);

    event WithDrawnFromProject(string indexed name, uint96 indexed amountWithdrawn, address indexed Withdrawer);

    event ProjectOpenedForVoting(string indexed name, uint64 indexed timeOpenForVoting, uint32 indexed projectId);

    event ProjectVotingProcessFinalized(string indexed name, uint32 indexed projectById, bool indexed voteResult);

    event RefundRequested(
        string indexed projectName, uint32 indexed projectId, address indexed funder, uint96 refundAmount
    );

    modifier onlyProjectOwner(uint32 _projectId) {

        address _projectOwner = projectById[_projectId].basics.owner;
        if (_projectOwner == address(0)) {
            revert StageRaise__ProjectNotFound();
        }

        if (_projectOwner != msg.sender) {
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

    constructor(address _usdc, address _usdt, address _busd) Ownable(msg.sender) {
        supportedTokens[_usdc] = true;
        tokenDecimals[_usdc] = 6;
        
        supportedTokens[_usdt] = true;
        tokenDecimals[_usdt] = 6;
        
        supportedTokens[_busd] = true;
        tokenDecimals[_busd] = 18;
    }

    //Functions

    function addSupportedToken(address _token, uint8 _decimals) external onlyOwner {
        if (_token == address(0)) {
            revert StageRaise__InvalidTokenAddress();
        }
        supportedTokens[_token] = true;
        tokenDecimals[_token] = _decimals;
    }

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

        if (!supportedTokens[params.paymentToken]) {
            revert StageRaise__TokenNotSupported();
        }

        if (params.minFunding >= params.maxFunding) {
            revert StageRaise__MinFundingMustBeLessThanMaxFunding();
        }

        s_projectCount++;

        ProjectBasics memory basics = ProjectBasics({
            name: params.name,
            description: params.description,
            owner: msg.sender,
            targetAmount: params.targetAmount,
            isActive: true,
            raisedAmount: 0,
            deadline: params.deadline,
            totalContributors: 0,
            projectId: s_projectCount,
            minFunding: params.minFunding,
            maxFunding: params.maxFunding,
            paymentToken: params.paymentToken
        });

        ProjectMilestone memory milestone = ProjectMilestone({
            milestoneCount: params.milestoneCount,
            milestoneBased: params.milestoneBased,
            milestoneStage: params.milestoneBased ? 1 : 0,
            openForMilestoneVotingStage: false,
            failedMilestoneStage: 0,
            votesForYes: 0,
            timeForMilestoneVotingProcess: params.timeForMileStoneVotingProcess,
            timeForTheVotingProcessToElapsed: 0,
            votesForNo: 0,
            votingRound: 1
        });

       
        Project storage newProject = projectById[s_projectCount];
        newProject.basics = basics;
        newProject.milestone = milestone;
        newProject.projectBalance = 0;
        newProject.amountWithdrawn = 0;

        emit ProjectCreated(params.name, params.targetAmount, params.deadline);
    }

    function fundProject(uint32 _projectId, uint96 _amount) external {
        if (_amount <= 0) {
            revert StageRaise__AmountToFundMustBeGreaterThanZero();
        }
        if (projectById[_projectId].basics.owner == address(0)) {
            revert StageRaise__ProjectNotFound();
        }
        if (!projectById[_projectId].basics.isActive) {
            revert StageRaise__ProjectNotActive();
        }

        address token = projectById[_projectId].basics.paymentToken;
        uint8 decimals = tokenDecimals[token];
        uint256 normalizedAmount = _normalizeAmount(_amount, decimals);

        if (normalizedAmount < projectById[_projectId].basics.minFunding) {
            revert StageRaise__FundingAmountBelowMinimum();
        }

        uint256 funderCurrentContribution = projectById[_projectId].contributorsToAmountFunded[msg.sender];
        if ((normalizedAmount + funderCurrentContribution) > projectById[_projectId].basics.maxFunding) {
            revert StageRaise__FundingAmountAboveMaximum();
        }

        if (normalizedAmount + projectById[_projectId].basics.raisedAmount > projectById[_projectId].basics.targetAmount) {
            revert StageRaise__TotalRaiseCantSurpassTargetRaise();
        }
        if (block.timestamp > projectById[_projectId].basics.deadline) {
            projectById[_projectId].basics.isActive = false;
            revert StageRaise__DeadlineForFundingHasPassed();
        }


        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);

        Project storage project = projectById[_projectId];
        if (project.contributorsToAmountFunded[msg.sender] == 0) {
            project.basics.totalContributors++;
        }
        project.basics.raisedAmount += normalizedAmount;
        project.projectBalance += uint96(normalizedAmount);
        project.contributorsToAmountFunded[msg.sender] += uint128(normalizedAmount);

        emit ProjectFunded(project.basics.name, uint96(normalizedAmount), msg.sender);
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
        project.milestone.votingRound++;
        project.milestone.openForMilestoneVotingStage = false;
        emit ProjectVotingProcessFinalized(project.basics.name, _projectId, voteResult);
    }

    function withdrawFunds(uint96 _amount, uint32 _projectId, address payable _to)
        external
        onlyProjectOwner(_projectId)
    {
        if (_amount <= 0) {
            revert StageRaise__AmountToWithdrawMustBeGreaterThanZero();
        }
        

        address token = projectById[_projectId].basics.paymentToken;
        uint8 decimals = tokenDecimals[token];
        uint256 normalizedAmount = _normalizeAmount(_amount, decimals);
        
        if (projectById[_projectId].projectBalance < normalizedAmount) {
            revert StageRaise__YouCannotWithdrawMoreThanTheProjectBalance();
        }

        if (_amount > getAmountWithdrawableForAProject(_projectId)) {
            revert StageRaise__YouCannotWithdrawMoreThanWithdrawableBalance();
        }

        if (block.timestamp <= projectById[_projectId].basics.deadline) {
            revert StageRaise__CannotWithdrawWhileFundingIsActive();
        }

        projectById[_projectId].projectBalance -= uint96(normalizedAmount);
        projectById[_projectId].amountWithdrawn += uint96(normalizedAmount);


        IERC20(token).safeTransfer(_to, _amount);

        emit WithDrawnFromProject(projectById[_projectId].basics.name, _amount, msg.sender);
    }

    function takeAVoteForMilestoneStageIncrease(uint32 _projectId, bool _vote)
        external
        onlyProjectFunder(_projectId)
    {
        Project storage project = projectById[_projectId];

        if (project.funderVotingRound[msg.sender] == project.milestone.votingRound) {
            revert StageRaise__FunderHasAlreadyVoted();
        }

        if (!project.milestone.openForMilestoneVotingStage) {
            revert StageRaise__ProjectIsNotOpenForMilestoneVotingProcess();
        }
        if (block.timestamp > project.milestone.timeForTheVotingProcessToElapsed) {
            revert StageRaise__VotingPeriodHasPassed();
        }
        
        uint256 votingPower = calculateFunderVotingPower(msg.sender, _projectId);
        
        if (_vote == true) {
            project.milestone.votesForYes += votingPower;
        } else {
            project.milestone.votesForNo += votingPower;
        }
   
        project.funderVotingRound[msg.sender] = project.milestone.votingRound;
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
        uint96 amountToRefund = uint96((funderContribution * remainingFundsForRefund) / project.basics.raisedAmount);

        if (amountToRefund <= 0) {
            revert StageRaise__AmountToWithdrawMustBeGreaterThanZero();
        }

        project.contributorsToAmountFunded[msg.sender] = 0;
        project.projectBalance -= amountToRefund;

   
        address token = project.basics.paymentToken;
        uint8 decimals = tokenDecimals[token];
        uint256 denormalizedAmount = _denormalizeAmount(amountToRefund, decimals);

        IERC20(token).safeTransfer(msg.sender, denormalizedAmount);

        emit RefundRequested(project.basics.name, _projectId, msg.sender, amountToRefund);
    }

    // view & pure functions

    function getProjectBasicInfo(uint32 _projectId) public view returns (ProjectInfo memory) {
        Project storage p = projectById[_projectId];

        return ProjectInfo({
            owner: p.basics.owner,
            paymentToken: p.basics.paymentToken,
            targetAmount: p.basics.targetAmount,
            raisedAmount: p.basics.raisedAmount,
            minFunding: p.basics.minFunding,
            maxFunding: p.basics.maxFunding,
            deadline: p.basics.deadline,
            projectId: p.basics.projectId,
            totalContributors: p.basics.totalContributors,
            milestoneCount: p.milestone.milestoneCount,
            isActive: p.basics.isActive,
            milestoneBased: p.milestone.milestoneBased,
            name: p.basics.name,
            description: p.basics.description
        });
    }

    function getAmountWithdrawableForAProject(uint32 _projectId) public view returns (uint96) {
        Project storage project = projectById[_projectId];
        if (project.basics.owner == address(0)) {
            return 0;
        }

        uint96 normalizedWithdrawable;
        if (!project.milestone.milestoneBased) {
            normalizedWithdrawable = project.projectBalance;
        } else {
            uint256 maxWithdrawable =
                (project.basics.raisedAmount * project.milestone.milestoneStage) / project.milestone.milestoneCount;
            normalizedWithdrawable = uint96(maxWithdrawable - project.amountWithdrawn);
        }
        

        address token = project.basics.paymentToken;
        uint8 decimals = tokenDecimals[token];
        return uint96(_denormalizeAmount(normalizedWithdrawable, decimals));
    }

    function calculateFunderVotingPower(address _funder, uint32 _projectId)
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

        uint128 amountFundedByTheFunder = project.contributorsToAmountFunded[_funder];

        votingPower = (uint256(amountFundedByTheFunder) * 1e18) / project.basics.raisedAmount;

        return votingPower;
    }

    function getProjectCount() public view returns (uint32) {
        return s_projectCount;
    }

    function getProjectBalance(uint32 _projectId) public view returns (uint96) {
        return projectById[_projectId].projectBalance;
    }

    function getProjectAmountWithdrawn(uint32 _projectId) public view returns (uint96) {
        return projectById[_projectId].amountWithdrawn;
    }

    function getProjectMilestoneStage(uint32 _projectId) public view returns (uint8) {
        return projectById[_projectId].milestone.milestoneStage;
    }

    function getProjectMileStoneVotingStatus(uint32 _projectId) public view returns (bool) {
        return projectById[_projectId].milestone.openForMilestoneVotingStage;
    }

    function getProjectYesVotes(uint32 _projectId) public view returns (uint256) {
        return projectById[_projectId].milestone.votesForYes;
    }

    function getProjectNoVotes(uint32 _projectId) public view returns (uint256) {
        return projectById[_projectId].milestone.votesForNo;
    }

    function getProjectMinFunding(uint32 _projectId) public view returns (uint96) {
        return projectById[_projectId].basics.minFunding;
    }

    function getProjectMaxFunding(uint32 _projectId) public view returns (uint96) {
        return projectById[_projectId].basics.maxFunding;
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

    function hasFunderVotedInCurrentRound(uint32 _projectId, address _funder) public view returns (bool) {
        Project storage project = projectById[_projectId];
        return project.funderVotingRound[_funder] == project.milestone.votingRound;
    }

    function getCurrentVotingRound(uint32 _projectId) public view returns (uint8) {
        return projectById[_projectId].milestone.votingRound;
    }

    function getProjectPaymentToken(uint32 _projectId) public view returns (address) {
        return projectById[_projectId].basics.paymentToken;
    }

    function getTokenDecimals(address _token) public view returns (uint8) {
        return tokenDecimals[_token];
    }

    function isTokenSupported(address _token) public view returns (bool) {
        return supportedTokens[_token];
    }

    // Internal helper functions for normalization

    function _normalizeAmount(uint256 _amount, uint8 _decimals) internal pure returns (uint256) {
        if (_decimals == 18) {
            return _amount;
        } else if (_decimals < 18) {
            return _amount * (10 ** (18 - _decimals));
        } else {
            revert("Unsupported decimals");
        }
    }

    function _denormalizeAmount(uint256 _amount, uint8 _decimals) internal pure returns (uint256) {
        if (_decimals == 18) {
            return _amount;
        } else if (_decimals < 18) {
            return _amount / (10 ** (18 - _decimals));
        } else {
            revert("Unsupported decimals");
        }
    }
}
