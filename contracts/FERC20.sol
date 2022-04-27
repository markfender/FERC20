// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Solidity fractal ERC20 implementation (mass adoption standard name: FractalCoin)
/// @author Mark Fender
contract FERC20 is ERC20 {

/*
	all transactions may be done only by members
	process all type of actions
	
	add function to exit from the member list
	what happens if there is not delegates?

	contract 1 lvl 2
		- add to contstructor list of child contracrs with balances
		- to participate in the voting you should be a delegate, only the name of your contract is assgind as vote address
		- the delegate should be only one
		- override balanceOf(
			person, contract_path[]
		) function, it should get the share of contract and get share of person
	
*/
	enum VotingStatus {
		Open,
		Closed
	}

	enum ActionType {
		AddMember,
		AddDelegate,
		RemoveMember,
		RemoveDelegate,
		MintTo,
		BurnFrom,
		UpdateParentContract
	}
	
	enum MemberType {
		Voter,
		Delegate
	}

	struct Action {
		ActionType actionType;
		address to;
		uint256 value;
	}

	struct Member {
		address memberAddress;
		MemberType memberType;
	}

	struct Voting {
		VotingStatus votingStatus;
		Action votingAction;
		uint256 threashold; // v0.0.1 set default
		address creator;
	}

	struct ChildContract {
		uint256 value;
		address childContract;
	}

	// Coin tree
	address public parentContract;
	ChildContract[] public childContracts;

	// Members
	Member[] members public;

	// Votings
	Voting[] public votingList;
	mapping(uint256 => address[]) public voteSupported;
	mapping(uint256 => address[]) public voteAgainst;

	// Constants
	uint256 private votesThreashold = 80; // in percents
	uint256 private limitOfActiveVoting = 3; // const which shows the max voting created by one user

	modifier onlyMember {
		require(checkIfAccountMember(msg.sender), "Account is not a member of the contract");
		_;
	}
	// todo: init the default state, values and members, threshold, voting_time
	// todo: add events
	constructor(address[] _initialMembers) ERC20("FractalCoin", "FERC") {
		if(_initialMembers.length != 0) {
			for (uint256 i = 0; i < _initialMembers.length; i++) {
				members.push({
					memberAddress: _initialMembers[i],
					memberType:  MemberType.Voter
				});
			}
		}
		// set initial members
	}

	function addVoting(Action memory _votingAction) onlyMember public {
		require(_votingLimit(msg.sender), "Vote creating limit exceeded");

		Voting memory newVoting;
		newVoting.votingStatus = VotingStatus.Open;
		newVoting.votingAction = _votingAction;
		newVoting.threashold = votesThreashold;
		newVoting.creator = msg.sender;

		votingList.push(newVoting);
	}

	/// decision - `true` adds you to supported, `false` - adds to against
	function vote(uint256 _votingId, bool _decision) onlyMember public {
		require(_canVote(msg.sender, _votingId), "Account has already voted");

		if(_decision) {
			voteSupported[_votingId].push(msg.sender);
		} else {
			voteAgainst[_votingId].push(msg.sender);
		}

		// check if we should close the voting after threshold is archived
	}

	function processVoting(uint256 _votingId) public {
		Voting memory _processVote = votingList[_votingId];
		//require(_processVote.votingStatus == VotingStatus.Closed, "Voting is not closed");

		// Add member
		if(_processVote.votingAction.actionType == ActionType.AddMember) {
			// todo: check if we can add (exists)
			members.push({
				memberAddress: _processVote.votingAction.to,
				memberType:  _processVote.votingAction.Voter
			});
		}

		// Add delegate
		if(_processVote.votingAction.actionType == ActionType.AddDelegate) {
			// todo: check not more than one
			// todo: check if we can add (exists)
			members.push({
				memberAddress: _processVote.votingAction.to,
				memberType:  _processVote.votingAction.Delegate
			});
		}

		// Remove member
		if(_processVote.votingAction.actionType == ActionType.RemoveMember) {
			// todo: check if we can add (exists)
			uint256 indexMember = getMemberIndex(_processVote.votingAction.to) - 1;
			require(indexMember != 0, "No such member");
			indexMember--;
			members[indexMember] = members[members.length - 1];
			members.pop();
		}
		
		// Mint tokens to somebody
		if(_processVote.votingAction.actionType == ActionType.MintTo) {
			_mint(
				_processVote.votingAction.to,
				_processVote.votingAction.value
			);
		}

		// Burn somebodies tokens
		if(_processVote.votingAction.actionType == ActionType.BurnFrom) {
			uint256 amountToBurn = _processVote.votingAction.value;
			if(balanceOf(_processVote.votingAction.to) < _processVote.votingAction.value) {
				amountToBurn = balanceOf(_processVote.votingAction.to);
			}

			_burn(
				_processVote.votingAction.to, //apply to
				amountToBurn
			);
		}

		// Update Parent Contract
		if(_processVote.votingAction.actionType == ActionType.UpdateParentContract) {
			// check if parent contract matches the requirements
			parentContract = _processVote.votingAction.to;
		}

		//Add child


		votingList[_votingId] = votingList[votingList.length - 1];
		votingList.pop();
		voteSupported[_votingId] = [];
		voteAgainst[_votingId] = [];
	}

	function checkIfAccountMember(address _account) public returns(bool) {
		// todo: implement function
		if(getMemberIndex(_account) == 0) return false;
		else return true;
	}

	function _canVote(address _account, uint256 _votingId) internal returns(bool) {
		// todo: implement function:
		//			check if supported or against,
		//			check if voting exists
		//			check if not delegated
		return true;
	}

	function _votingLimit(address _account) internal returns(bool) {
		return true;
	}

	function _checkChildForCircles(address _account) internal returns(bool){
		return true;
	}
	
	function _checkParentForCircles(address _account) internal returns(bool){
		return true;
	}

	function getNumberOfSupporters(uint256 _votingId) public view returns(uint256) {
		return voteSupported[_votingId].length;
	}

	function getNumberOfAgainst(uint256 _votingId) public view returns(uint256) {
		return voteAgainst[_votingId].length;
	}

	function getMemberIndex(address _member) public returns(uint256) {
		for (int i = 1 ; i <= members.length; i++) {
			if (members[i-1].memberAddress == _member) {
				return i;
			}
		}
		return 0;
	}

}
