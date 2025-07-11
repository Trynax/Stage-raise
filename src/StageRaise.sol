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

contract  StageRaise {

    //Errors 



    //Types


    struct Project {
        address owner; 
        string name;
        string description;
        uint256 targetAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        uint256 totalContributors;
        uint256 milestoneCount;
        bool milestoneBased;

    }

    //State Variables
    Project[] public s_projects;
    mapping(uint256 => Project) public projectById;
    uint256 public projectCount;





    //Functions 


    function createProject(string memory _name, string memory  _description, uint256 _targetAmount, uint256 _deadline, bool _isActive, uint256 _milestoneCount, bool _milestoneBased)  public{
        if (block.timestamp >= _deadline){
            revert StageRaise__DeadlineMustBeInFuture();
        }
        if (_targetAmount <= 0 ){
            revert StageRaise__TargetAmountMustBeGreaterThanZero();
        }


        Project memory newProject = Project({
            owner:msg.sender,
            name: _name,
            description: _description,
            targetAmount: _targetAmount,
            raisedAmount: 0,
            deadline: _deadline,
            isActive: _isActive,
            totalContributors: 0,
            milestoneCount: _milestoneCount,
            milestoneBased: _milestoneBased

        });

        projectCount++;
        projectById[projectCount] = newProject;
        s_projects.push(newProject);
    } 


    


    // view & pure functions

    function getProject(uint256 _proejectId) public view returns(Project memory){
        return projectById[_proejectId];
    }

}