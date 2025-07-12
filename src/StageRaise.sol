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
error StageRaise__ProjectNotActive();
error StageRaise__ProjectNotFound();
error StageRaise__TotalRaiseCantSurpassTargetRaise();

contract  StageRaise {

    //Errors 

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
        address[] contributors;
        mapping(address => uint256) contibutorsToAmountFunded;
    }

    //State Variables
    Project[] public s_projects;
    mapping(uint256 => Project) public projectById;
    uint256 public s_projectCount;

    //Events 

    event ProjectCreated (string indexed name, uint256 indexed targetAmount, uint256 deadline);
    event ProjectFunded (string indexed name, uint256 indexed AmoutFunded, address indexed Funder);



    //Functions 


    function createProject(string memory _name, string memory  _description, uint256 _targetAmount, uint256 _deadline, bool _isActive, uint256 _milestoneCount, bool _milestoneBased)  public{
        if (block.timestamp >= _deadline){
            revert StageRaise__DeadlineMustBeInFuture();
        }
        if (_targetAmount <= 0 ){
            revert StageRaise__TargetAmountMustBeGreaterThanZero();
        }
        
        s_projectCount++;

        Project storage newProject = projectById[s_projectCount];

        newProject.name = _name;
        newProject.owner=msg.sender;
        newProject.projectId= s_projectCount;
        newProject.description= _description;
        newProject.targetAmount=_targetAmount;
        newProject.raisedAmount = 0;
        newProject.deadline=_deadline;
        newProject.isActive=_isActive;
        newProject.totalContributors=0;
        newProject.totalContributors=0;
        newProject.milestoneCount=_milestoneCount;
        newProject.milestoneBased = _milestoneBased;
    } 


    function fundProject( uint256 _projectId) payable  external {

        if (msg.value <= 0 ){
            revert StageRaise__AmountToFundMustBeGreaterThanZero();
        }
        if (projectById[_projectId].owner == address(0)){
            revert StageRaise__ProjectNotFound();
        }
        if (!projectById[_projectId].isActive){
            revert StageRaise__ProjectNotActive();
        }
        if(msg.value+ projectById[_projectId].raisedAmount > projectById[_projectId].targetAmount){
            revert  StageRaise__TotalRaiseCantSurpassTargetRaise();

        }
        Project storage project = projectById[_projectId];
        project.raisedAmount += msg.value;
        project.contributors.push(msg.sender);
        project.totalContributors = project.contributors.length;
        project.contibutorsToAmountFunded[msg.sender] += msg.value;
    }


    


    // view & pure functions

    function getProjectBasicInfo(uint256 _projectId) public view returns(address owner, string memory name, string memory decription, uint256 targetAmount, uint256 raisedAmount, uint256 deadline, bool isActive, uint256 totalContributors, uint256 milestoneCount, bool milestoneBased){

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



}