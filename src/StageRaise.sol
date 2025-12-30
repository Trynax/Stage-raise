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

/// @title StageRaise - Decentralized funding with Milestone-Based Fund Release
/// @author Trynax
/// @notice A funding platform that supports stablecoin payments with milestone-based voting for fund release
/// @dev Implements milestone voting system where funders vote on project progress before funds are released
contract StageRaise is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Core project information optimized for gas efficiency
    /// @dev Storage packed into 5+ slots (5 fixed + dynamic strings)
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

    /// @notice Milestone voting configuration and state
    /// @dev Storage packed into 3 slots for gas efficiency
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

    /// @notice Complete project state including basics, milestones, and funder tracking
    /// @dev Combines all project data with mappings for contributor tracking
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

    /// @notice Public view of project information for external queries
    /// @dev Used by getProjectBasicInfo() to return project data
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

    /// @notice Parameters for creating a new project
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

    /// @notice Mapping of project ID to project data
    mapping(uint32 => Project) public projectById;
    
    /// @notice Counter for generating unique project IDs
    uint32 private s_projectCount;
    
    /// @notice Stablecoin addresses that are accepted for funding
    mapping(address => bool) public supportedTokens;
    
    /// @notice Decimal places for each supported token (e.g., 6 for USDC, 18 for BUSD)
    mapping(address => uint8) public tokenDecimals;

    /// @notice Emitted when a new project is created
    /// @param name Project name
    /// @param targetAmount Funding goal in normalized 18 decimals
    /// @param deadline Timestamp when funding period ends
    event ProjectCreated(string indexed name, uint256 indexed targetAmount, uint64 indexed deadline);
    
    /// @notice Emitted when a project receives funding
    /// @param name Project name
    /// @param amountFunded Amount funded in normalized 18 decimals
    /// @param funder Address of the funder
    event ProjectFunded(string indexed name, uint96 indexed amountFunded, address indexed funder);

    /// @notice Emitted when project owner withdraws funds
    /// @param name Project name
    /// @param amountWithdrawn Amount withdrawn in token's native decimals
    /// @param Withdrawer Address of the withdrawer
    event WithDrawnFromProject(string indexed name, uint96 indexed amountWithdrawn, address indexed Withdrawer);

    /// @notice Emitted when a milestone project is opened for voting
    /// @param name Project name
    /// @param timeOpenForVoting Timestamp when voting period ends
    /// @param projectId ID of the project
    event ProjectOpenedForVoting(string indexed name, uint64 indexed timeOpenForVoting, uint32 indexed projectId);

    /// @notice Emitted when voting period ends and results are finalized
    /// @param name Project name
    /// @param projectById ID of the project
    /// @param voteResult True if milestone passed, false if failed
    event ProjectVotingProcessFinalized(string indexed name, uint32 indexed projectById, bool indexed voteResult);

    /// @notice Emitted when a funder requests a refund after 3 failed milestones
    /// @param projectName Name of the project
    /// @param projectId ID of the project
    /// @param funder Address requesting refund
    /// @param refundAmount Amount refunded in normalized 18 decimals
    event RefundRequested(
        string indexed projectName, uint32 indexed projectId, address indexed funder, uint96 refundAmount
    );

    /// @notice Restricts function access to the project owner only
    /// @param _projectId ID of the project to check ownership
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

    /// @notice Restricts function access to addresses that have funded the project
    /// @param _projectId ID of the project to check funding status
    modifier onlyProjectFunder(uint32 _projectId) {
        if (projectById[_projectId].contributorsToAmountFunded[msg.sender] == 0) {
            revert StageRaise__AddressHasNotFundTheProject();
        }

        _;
    }

    /// @notice Initializes the contract with supported stablecoins
    constructor(address _usdc, address _usdt, address _busd) Ownable(msg.sender) {
        supportedTokens[_usdc] = true;
        tokenDecimals[_usdc] = 6;
        
        supportedTokens[_usdt] = true;
        tokenDecimals[_usdt] = 6;
        
        supportedTokens[_busd] = true;
        tokenDecimals[_busd] = 18;
    }

    //Functions

    /// @notice Adds a new supported stablecoin
    /// @param _token Address of the stablecoin token
    /// @param _decimals Number of decimals the token uses
    function addSupportedToken(address _token, uint8 _decimals) external onlyOwner {
        if (_token == address(0)) {
            revert StageRaise__InvalidTokenAddress();
        }
        supportedTokens[_token] = true;
        tokenDecimals[_token] = _decimals;
    }

    /// @notice Removes a supported stablecoin
    /// @param _token Address of the stablecoin token to remove
    function removeSupportedToken(address _token) external onlyOwner {
        if (_token == address(0)) {
            revert StageRaise__InvalidTokenAddress();
        }
        supportedTokens[_token] = false;
        tokenDecimals[_token] = 0;
    }

    
    /// @notice Creates a new crowdfunding project
    /// @dev All amounts are normalized to 18 decimals internally
    /// @param params Project parameters including target, deadline, milestones, and token
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

    /// @notice Fund a project with stablecoins
    /// @dev Amount is in token's native decimals, gets normalized internally
    /// @param _projectId ID of the project to fund
    /// @param _amount Amount to fund in token's native decimals
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

    /// @notice Opens a milestone project for community voting
    /// @dev Only callable by project owner after funding period ends
    /// @param _projectId ID of the project to open for voting
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

    /// @notice Finalizes the voting process and updates milestone stage based on results
    /// @dev Can be called by anyone after voting period ends
    /// @param _projectId ID of the project to finalize voting for
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

    /// @notice Allows project owner to withdraw funds based on milestone progress
    /// @dev Amount must be within withdrawable limit for current milestone stage
    /// @param _amount Amount to withdraw in token's native decimals
    /// @param _projectId ID of the project
    /// @param _to Address to send withdrawn funds to
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

    /// @notice Allows funders to vote on milestone completion
    /// @dev Voting power is proportional to funding contribution
    /// @param _projectId ID of the project to vote on
    /// @param _vote True for yes (milestone passed), false for no (milestone failed)
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

    /// @notice Allows funders to request a refund after 3 failed milestones
    /// @dev Refund is proportional to contribution minus already withdrawn amounts
    /// @param _projectId ID of the project to request refund from
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

    /// @notice Returns detailed information about a project
    /// @param _projectId ID of the project to query
    /// @return ProjectInfo struct containing all project details
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

    /// @notice Calculates how much the project owner can currently withdraw
    /// @dev For milestone projects, amount is based on completed stages
    /// @param _projectId ID of the project to check
    /// @return Maximum withdrawable amount in token's native decimals
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

    /// @notice Calculates a funder's voting power as a percentage of total raised
    /// @dev Returns value in 18 decimals (1e18 = 100%)
    /// @param _funder Address of the funder
    /// @param _projectId ID of the project
    /// @return votingPower Voting power from 0 to 1e18 (0% to 100%)
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

    /// @notice Returns the total number of projects created
    /// @return Total project count
    function getProjectCount() public view returns (uint32) {
        return s_projectCount;
    }

    /// @notice Returns the current balance of a project in normalized 18 decimals
    /// @param _projectId ID of the project
    /// @return Project balance in 18 decimals
    function getProjectBalance(uint32 _projectId) public view returns (uint96) {
        return projectById[_projectId].projectBalance;
    }

    /// @notice Returns total amount already withdrawn by project owner
    /// @param _projectId ID of the project
    /// @return Amount withdrawn in 18 decimals
    function getProjectAmountWithdrawn(uint32 _projectId) public view returns (uint96) {
        return projectById[_projectId].amountWithdrawn;
    }

    /// @notice Returns the current milestone stage of a project
    /// @param _projectId ID of the project
    /// @return Current milestone stage (0 for non-milestone projects)
    function getProjectMilestoneStage(uint32 _projectId) public view returns (uint8) {
        return projectById[_projectId].milestone.milestoneStage;
    }

    /// @notice Checks if a project is currently open for voting
    /// @param _projectId ID of the project
    /// @return True if voting is open, false otherwise
    function getProjectMileStoneVotingStatus(uint32 _projectId) public view returns (bool) {
        return projectById[_projectId].milestone.openForMilestoneVotingStage;
    }

    /// @notice Returns the total 'yes' votes for current voting round
    /// @param _projectId ID of the project
    /// @return Total yes votes in 18 decimal format
    function getProjectYesVotes(uint32 _projectId) public view returns (uint256) {
        return projectById[_projectId].milestone.votesForYes;
    }

    /// @notice Returns the total 'no' votes for current voting round
    /// @param _projectId ID of the project
    /// @return Total no votes in 18 decimal format
    function getProjectNoVotes(uint32 _projectId) public view returns (uint256) {
        return projectById[_projectId].milestone.votesForNo;
    }

    /// @notice Returns the minimum funding amount per contribution
    /// @param _projectId ID of the project
    /// @return Minimum funding amount in 18 decimals
    function getProjectMinFunding(uint32 _projectId) public view returns (uint96) {
        return projectById[_projectId].basics.minFunding;
    }

    /// @notice Returns the maximum funding amount per contributor
    /// @param _projectId ID of the project
    /// @return Maximum funding amount in 18 decimals
    function getProjectMaxFunding(uint32 _projectId) public view returns (uint96) {
        return projectById[_projectId].basics.maxFunding;
    }

    /// @notice Returns the number of failed milestone votes
    /// @param _projectId ID of the project
    /// @return Number of failed milestones (max 3 before refunds allowed)
    function getProjectFailedMilestoneStage(uint32 _projectId) public view returns (uint8) {
        return projectById[_projectId].milestone.failedMilestoneStage;
    }

    /// @notice Returns the amount a specific contributor has funded
    /// @param _projectId ID of the project
    /// @param _contributor Address of the contributor
    /// @return Amount contributed in 18 decimals
    function getProjectContributorAmount(uint32 _projectId, address _contributor) public view returns (uint128) {
        return projectById[_projectId].contributorsToAmountFunded[_contributor];
    }

    /// @notice Returns the timestamp when current voting period ends
    /// @param _projectId ID of the project
    /// @return Unix timestamp of voting end time
    function getProjectVotingEndTime(uint32 _projectId) public view returns (uint64) {
        return projectById[_projectId].milestone.timeForTheVotingProcessToElapsed;
    }

    /// @notice Checks if a funder has voted in the current voting round
    /// @param _projectId ID of the project
    /// @param _funder Address of the funder
    /// @return True if already voted, false otherwise
    function hasFunderVotedInCurrentRound(uint32 _projectId, address _funder) public view returns (bool) {
        Project storage project = projectById[_projectId];
        return project.funderVotingRound[_funder] == project.milestone.votingRound;
    }

    /// @notice Returns the current voting round number
    /// @param _projectId ID of the project
    /// @return Current voting round (starts at 1)
    function getCurrentVotingRound(uint32 _projectId) public view returns (uint8) {
        return projectById[_projectId].milestone.votingRound;
    }

    /// @notice Returns the payment token address for a project
    /// @param _projectId ID of the project
    /// @return Address of the stablecoin used for this project
    function getProjectPaymentToken(uint32 _projectId) public view returns (address) {
        return projectById[_projectId].basics.paymentToken;
    }

    /// @notice Returns the decimal places for a token
    /// @param _token Address of the token
    /// @return Number of decimals (e.g., 6 for USDC, 18 for BUSD)
    function getTokenDecimals(address _token) public view returns (uint8) {
        return tokenDecimals[_token];
    }

    /// @notice Checks if a token is supported for funding
    /// @param _token Address of the token
    /// @return True if token is supported, false otherwise
    function isTokenSupported(address _token) public view returns (bool) {
        return supportedTokens[_token];
    }

    /// @notice Converts token amount to normalized 18 decimal format
    /// @dev Used internally for consistent calculations across different tokens
    /// @param _amount Amount in token's native decimals
    /// @param _decimals Number of decimals the token uses
    /// @return Amount normalized to 18 decimals
    function _normalizeAmount(uint256 _amount, uint8 _decimals) internal pure returns (uint256) {
        if (_decimals == 18) {
            return _amount;
        } else if (_decimals < 18) {
            return _amount * (10 ** (18 - _decimals));
        } else {
            revert("Unsupported decimals");
        }
    }

    /// @notice Converts normalized 18 decimal amount back to token's native decimals
    /// @dev Used internally when transferring tokens to users
    /// @param _amount Amount in normalized 18 decimals
    /// @param _decimals Number of decimals the token uses
    /// @return Amount in token's native decimals
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
