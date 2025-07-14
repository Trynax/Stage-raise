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

//Error

error StageRaise__DeadlineMustBeInFuture();
error StageRaise__TargetAmountMustBeGreaterThanZero();
error StageRaise__AmountToFundMustBeGreaterThanZero();
error StageRaise__AmountToWithdrawMustBeGreaterThanZero();
error StageRaise__ProjectNotActive();
error StageRaise__ProjectNotFound();
error StageRaise__TotalRaiseCantSurpassTargetRaise();
error StageRaise__FundsCanOnlyBeWithdrawByProjectOwner();
error StageRaise__ETHTransferFailed();
error StageRaise__YouCannotWithdrawFromActiveProject();
error StageRaise__YouCannotWithdrawMoreThanTheProjectBalance();
error StageRaise__YoucannotHaveZeroMilestoneForAMileStoneProject();
error StageRaise__YoucannotWithdrawMoreThanWithdrawableBalance();

contract StageRaise {

    //Types

    struct Project {
        address owner;
        uint256 projectId;
        string name;
        string description;
        uint256 targetAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        uint256 totalContributors;
        uint256 milestoneCount;
        bool milestoneBased;
        uint256 projectBalance;
        uint256 amountWithdrawn;
        uint256 milestoneStage;
        mapping(address => uint256) contributorsToAmountFunded;
    }

    //State Variables
    mapping(uint256 => Project) public projectById;
    uint256 private s_projectCount;

    //Events

    event ProjectCreated(
        string indexed name,
        uint256 indexed targetAmount,
        uint256 indexed deadline
    );
    event ProjectFunded(
        string indexed name,
        uint256 indexed amountFunded,
        address indexed funder
    );

    event WithDrawnFromProject(
        string indexed name,
        uint256 indexed amountWithdrawn,
        address indexed Withdrawer
    );
    //Modifier

    modifier onlyProjectOwner (uint256 _projectId, address _withdrawerAddress){

        if(projectById[_projectId].owner != _withdrawerAddress){
            revert StageRaise__FundsCanOnlyBeWithdrawByProjectOwner();
        }
        _;
    }

    //Functions

    function createProject(
        string memory _name,
        string memory _description,
        uint256 _targetAmount,
        uint256 _deadline,
        bool _isActive,
        uint256 _milestoneCount,
        bool _milestoneBased
    ) external {
        if (block.timestamp >= _deadline) {
            revert StageRaise__DeadlineMustBeInFuture();
        }
        if (_targetAmount <= 0) {
            revert StageRaise__TargetAmountMustBeGreaterThanZero();
        }

        if (_milestoneBased != false && _milestoneCount <=0){
            revert StageRaise__YoucannotHaveZeroMilestoneForAMileStoneProject();
        }

        s_projectCount++;

        Project storage newProject = projectById[s_projectCount];

        newProject.name = _name;
        newProject.owner = msg.sender;
        newProject.projectId = s_projectCount;
        newProject.description = _description;
        newProject.targetAmount = _targetAmount;
        newProject.raisedAmount = 0;
        newProject.projectBalance=0;

        newProject.deadline = _deadline;
        newProject.isActive = _isActive;
        newProject.totalContributors = 0;
        if (_milestoneBased == true){
             newProject.milestoneStage=1;
        }
       
        newProject.amountWithdrawn=0;
        newProject.milestoneCount = _milestoneCount;
        newProject.milestoneBased = _milestoneBased;

        emit ProjectCreated(_name, _targetAmount, _deadline);
    }

    function fundProject(uint256 _projectId) external payable {
        if (msg.value <= 0) {
            revert StageRaise__AmountToFundMustBeGreaterThanZero();
        }
        if (projectById[_projectId].owner == address(0)) {
            revert StageRaise__ProjectNotFound();
        }
        if (!projectById[_projectId].isActive) {
            revert StageRaise__ProjectNotActive();
        }
        if (
            msg.value + projectById[_projectId].raisedAmount >
            projectById[_projectId].targetAmount
        ) {
            revert StageRaise__TotalRaiseCantSurpassTargetRaise();
        }
        if (block.timestamp > projectById[_projectId].deadline) {
            revert StageRaise__DeadlineMustBeInFuture();
        }
        Project storage project = projectById[_projectId];
        if (project.contributorsToAmountFunded[msg.sender] == 0) {
            project.totalContributors++;
        }
        project.raisedAmount += msg.value;
        project.projectBalance +=msg.value;
        project.contributorsToAmountFunded[msg.sender] += msg.value;

        emit ProjectFunded(project.name, msg.value, msg.sender);
    }

    function withdrawFunds(uint256 _amount, uint256 _projectId, address payable _to) external  onlyProjectOwner(_projectId, msg.sender){
        if (projectById[_projectId].owner == address(0)){
            revert StageRaise__ProjectNotFound();
        }
        if (_amount <= 0 ){
            revert StageRaise__AmountToWithdrawMustBeGreaterThanZero();
        }
        if(projectById[_projectId].isActive){
            revert StageRaise__YouCannotWithdrawFromActiveProject();
        }
        if(projectById[_projectId].projectBalance < _amount){
            revert StageRaise__YouCannotWithdrawMoreThanTheProjectBalance();
        }
        if(_amount > getAmountWithdrawableForAProject(_projectId)){
            revert StageRaise__YoucannotWithdrawMoreThanWithdrawableBalance();
        }

        projectById[_projectId].projectBalance -= _amount;
        projectById[_projectId].amountWithdrawn += _amount;
        (bool success, ) = _to.call{value:_amount}("");

        if (!success){
            revert StageRaise__ETHTransferFailed();
        }

        emit WithDrawnFromProject(projectById[_projectId].name, _amount, msg.sender);
    }
    // view & pure functions

    function getProjectBasicInfo(
        uint256 _projectId
    )
        public
        view
        returns (
            address owner,
            string memory name,
            string memory description,
            uint256 targetAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool isActive,
            uint256 totalContributors,
            uint256 milestoneCount,
            bool milestoneBased
        )
    {
        Project storage p = projectById[_projectId];

        return (
            p.owner,
            p.name,
            p.description,
            p.targetAmount,
            p.raisedAmount,
            p.deadline,
            p.isActive,
            p.totalContributors,
            p.milestoneCount,
            p.milestoneBased
        );
    }

    function getAmountWithdrawableForAProject(uint256 _projectId) public view returns(uint256){

        Project storage project = projectById[_projectId];
        if(project.owner == address(0)){
            return 0;
        }

        if(!project.milestoneBased){
            return project.projectBalance;
        }

        uint256 maxWithdrawable = (project.raisedAmount * project.milestoneStage)/ project.milestoneCount;
        uint256 maxWithdrawableNow= maxWithdrawable-project.amountWithdrawn;
        return maxWithdrawableNow;
    }


    function getProjectCount() public view returns (uint256) {
        return s_projectCount;
    }
}
