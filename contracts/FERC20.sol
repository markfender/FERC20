// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

interface IFERC20 {
	enum MemberType {
		Voter,
		Delegate
	}

	struct Member {
		address memberAddress;
		MemberType memberType;
	}

	struct ChildContract {
		address childContract;
		uint256 value;
	}

	function checkIfAccountMember(address) external view virtual returns(bool);

	function getPathToContract(address[] memory) external view virtual returns(address[] memory);
	function getShareBalancePath(address[] memory) external view virtual returns(uint256);
	function getShareAmountPath(address[] memory, uint256) external view virtual returns(uint256);
	function checkPathToMember(address[] memory) external view virtual returns(bool);
	function pathTransfer(address[] memory, uint256) external virtual;

	function getMemberIndex(address) external view virtual returns(uint256);
	function getChildContractIndex(address) external view virtual returns(uint256);
	function getAllMembers() external view virtual returns (Member[] memory);
	function getAllChildContracts() external view virtual returns(ChildContract[] memory);
}

/// @title Solidity fractal ERC20 implementation (mass adoption standard name: FractalCoin)
/// @author Mark Fender
contract FERC20 is IFERC20, ERC20 {

/*
	!!!! ADD MEMBER TO A PARENT CONTRACT ON init
	todo: chech if child contract proved that it is a parent contract
	balanceOf override
	transfer override

	members chould be added by voting only if no child contrats exists
	if at least one child contract all members should be attached to the contracts

	transfer([
		N_level_contract - top level,
		N-1_level_contract,
		N-2_level_contract,
		address_of_the_owner
	])

	constructor(
		["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"],
		[]
	)
	addVoting (
		[1, "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", 100]
	)
	vote(
		[0, true]
	)
	processVoting(0)
	---
	[0, "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2", 100]
	[6, "0x2E9d30761DB97706C536A112B9466433032b28e3", 0]

	check:
	["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", "0xf8e81D47203A594245E36C48e151709F0C19fBe8", "0x358AA13c52544ECCEF6B0ADD0f801012ADAD5eE3"]
	["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", "0x5FD6eB55D12E759a21C09eF703fe0CBa1DC9d88D", "0xe2899bddFD890e320e643044c6b95B9B0b84157A"]
	["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", "0xe2899bddFD890e320e643044c6b95B9B0b84157A"]

	getBalance:
	["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2", "0x838F9b8228a5C95a7c431bcDAb58E289f5D2A4DC"]

	[PARENT_CONTRACT_1_1, PARENT_CONTRACT_2, PARENT_CONTRACT_1_2, RECIPIENT_ADDRESS]

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
		AddMember, // 0
		AddDelegate, // 1
		RemoveMember, // 2
		RemoveDelegate, // 3
		MintTo, // 4
		BurnFrom, // 5
		UpdateParentContract, // 6
		AddChildContract, // 7
		RemoveChildContract // 8
	}

	struct Action {
		ActionType actionType;
		address to;
		uint256 value;
	}

	struct Voting {
		VotingStatus votingStatus;
		Action votingAction;
		uint256 threashold; // v0.0.1 set default
		address creator;
	}

	// Coin tree
	address public parentContract;
	ChildContract[] public childContracts;

	// Members
	Member[] public members;

	// Votings
	Voting[] public votingList;
	mapping(uint256 => address[]) public voteSupported;
	mapping(uint256 => address[]) public voteAgainst;

	// Constants
	// todo: add MAX deps
	// todo: add precision constant 
	// todo: all contracts should have the same precision constant
	uint256 private precision = 10000;
	uint256 private votesThreashold = 80; // in percents
	uint256 private limitOfActiveVotings = 3; // const which shows the max voting created by one user

	modifier onlyMember {
		require(checkIfAccountMember(msg.sender), ""); //Account is not a member of the contract
		_;
	}

	modifier onlyDelegatedMembers {
		if(childContracts.length == 0)
			require(checkIfAccountMember(msg.sender), ""); // Account is not a member of the contract
		else
			require(checkIfAccountIsDelegatedFromChildContract(msg.sender), ""); //Account is not delegate

		_;
	}
	// todo: init the default state, values and members, threshold, voting_time
	// todo: add events
	constructor(
		address[] memory _initialMembers,
		ChildContract[] memory _initialChildContracts
	) ERC20("FractalCoin", "FERC") {
		// set initial child contracts
		if(_initialChildContracts.length != 0) {
			for (uint256 i = 0; i < _initialChildContracts.length; i++) {
				_addChildContract(ChildContract(
					_initialChildContracts[i].childContract,
					_initialChildContracts[i].value
				));
			}
		}

		// set initial members
		if(_initialMembers.length != 0) {
			for (uint256 i = 0; i < _initialMembers.length; i++) {
				_addMember(Member(
					_initialMembers[i],
					MemberType.Voter
				));
			}
		}

		// testing: only for testing purpose
		_mint(msg.sender, 100);
	}

	function addVoting(Action memory _votingAction) public onlyMember {
		require(_votingLimit(msg.sender), ""); //Vote creating limit exceeded

		Voting memory newVoting;
		newVoting.votingStatus = VotingStatus.Open;
		newVoting.votingAction = _votingAction;
		newVoting.threashold = votesThreashold;
		newVoting.creator = msg.sender;

		votingList.push(newVoting);
	}

	/// decision - `true` adds you to supported, `false` - adds to against
	function vote(uint256 _votingId, bool _decision) public onlyMember/* onlyDelegatedMembers */{
		require(_canVote(msg.sender, _votingId), ""); //Account has already voted

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
			_addMember(Member(
				_processVote.votingAction.to,
				MemberType.Voter
			));

			_mint(
				_processVote.votingAction.to,
				_processVote.votingAction.value
			);
		}

		// Add delegate
		if(_processVote.votingAction.actionType == ActionType.AddDelegate) {
			// todo: check not more than one
			// todo: check if we can add (exists)
			_addMember(Member(
				_processVote.votingAction.to,
				MemberType.Delegate
			));
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
		// todo: vheck if contract
		if(_processVote.votingAction.actionType == ActionType.MintTo) {
			//todo: redistribute among communities
			_mint(
				_processVote.votingAction.to,
				_processVote.votingAction.value
			);
		}

		// Burn somebodies tokens
		// todo: vheck if contract
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
			require(isContract(_processVote.votingAction.to), "Not a contract");
			require(
				IFERC20(_processVote.votingAction.to).getChildContractIndex(address(this)) != 0,
				"Parent contract does not have such child"
			);

			parentContract = _processVote.votingAction.to;
		}

		//Add child
		if(_processVote.votingAction.actionType == ActionType.AddChildContract) {
			_addChildContract(ChildContract(
				_processVote.votingAction.to,
				_processVote.votingAction.value
			));
		}

		votingList[_votingId] = votingList[votingList.length - 1];
		votingList.pop();

		delete voteSupported[_votingId];
		delete voteAgainst[_votingId];
	}

	function _addMember(Member memory _member) private {
		if(childContracts.length > 0)
			require(checkIfAccountIsDelegatedFromChildContract(_member.memberAddress), "");//No such member in the child contract

		// check if no such voter exists in the list
		uint256 memberIndex = getMemberIndex(_member.memberAddress);

		if(_member.memberType == MemberType.Voter && memberIndex == 0) {
			members.push(_member);
		} else if(_member.memberType == MemberType.Delegate && memberIndex != 0) {	
			members[memberIndex - 1] = _member;
		} else if(_member.memberType == MemberType.Delegate && memberIndex == 0) {
			revert("");//delegate is not a member
			//members.push(_member);
		}
	}

	function _addChildContract(ChildContract memory _contract) private {
		require(isContract(_contract.childContract), ""); //It is not a contract
		require(getChildContractIndex(_contract.childContract) == 0, ""); //It is a child contract already
		// todo: check for circules
		require(_checkChildForCircles(_contract.childContract), ""); //The contract tree is cycled

		childContracts.push(_contract);
	}

	function checkIfAccountMember(address _account) public view override returns(bool) {
		// todo: implement function
		if(getMemberIndex(_account) == 0) return false;
		else return true;
	}

	function _canVote(address _account, uint256 _votingId) internal view returns(bool) {
		// todo: implement function:
		//			check if supported or against,
		//			check if voting exists
		//			check if not delegated
		return true;
	}

	function _votingLimit(address _account) internal view returns(bool) {
		return true;
	}

	function _checkChildForCircles(address _contract) internal view returns(bool){
		return true;
	}
	
	function _checkParentForCircles(address _account) internal view returns(bool){
		return true;
	}

	// [user_address, contract_1, contract_2, contract_3]
	function checkPathToMember(address[] memory _addressPath) public view override returns(bool) {
		// todo: maybe caller should be only parent or child
		if(_addressPath.length > 1) {
			// todo: Optimize storage use
			// `childContracts.length == 0` check is needed to make sure that the function would not be trigered on the delegate member
			if(_addressPath[1] == address(this) && childContracts.length == 0 &&  _addressPath.length == 2) {
				return checkIfAccountMember(_addressPath[0]);
			} else if (_addressPath[_addressPath.length - 1] != address(this)) {
				if(parentContract != address(0)) {
					return IFERC20(parentContract).checkPathToMember(_addressPath);
				} else {
					return false;
				}
			} else if(_addressPath[_addressPath.length - 1] == address(this)) {		
				return IFERC20(_addressPath[_addressPath.length - 2]).checkPathToMember(_arrayPopClone(_addressPath));
			}


			// if [1] = address(this):
				//checkIfAccountMember(0)
			// if n - 1 NOT equal to address(this):
				// call parent function with same args
			// if n - 1 equal to address(this):
				// pop last element and call checkPath(n[].pop())
		} else {
			return checkIfAccountMember(_addressPath[0]);
		}
	}
	
	function getAmountPath(address[] memory _addressPath, uint256 _amount) public view returns(uint256){
		// todo: check if proper path

		return getShareAmountPath(_addressPath, _amount)
			* IFERC20(_addressPath[_addressPath.length - 1]).getAllChildContracts()[
				IFERC20(_addressPath[_addressPath.length - 1]).getChildContractIndex(_addressPath[_addressPath.length - 2]) - 1
			].value / (precision**(_addressPath.length - 2)); // if we exo to `length - 1` then we may significantly loss precision 
	}

	// todo: add function to calculate if sender has enough balance
	function getBalancePath(address[] memory _addressPath) public view returns(uint256){
		// todo: check if proper path

		return getShareBalancePath(_addressPath)
			* IFERC20(_addressPath[_addressPath.length - 1]).getAllChildContracts()[
				IFERC20(_addressPath[_addressPath.length - 1]).getChildContractIndex(_addressPath[_addressPath.length - 2]) - 1
			].value / (precision**(_addressPath.length - 2)); // if we exo to `length - 1` then we may significantly loss precision 
	}

	// _addressPath - path to the recipient, from parent contract ot the low level
	// _amount - amount in the initial contract
	function pathTransfer(address[] memory _addressPath, uint256 _amount) public override {
		// verify msg.sender
		// get path to sender, get path to reciver
		// chech if path is ok
		// get sender amount
		// check if sender has enough amount
		// burn sender tokens
		// redestribute getter chain contracts

		/*
			u_0 u_1     u_2  u_3
			100 150     100  150
			100 (30)    100 (30)
					60

			transfer(u_1 -> u_2, 50)

			u_0 u_1     u_2  u_3
			100 150     225  150
			100 (24)    150 (36)
					60

			0.2 60 = 12


			24  == 36
			100 == 150

			x = 3600/24
			0.2

			375 - 250

			totalAmout - allExcept(getter) = new geeter value
		*/
		console.log(IERC20(_addressPath[1]).totalSupply());
	}

	function calculateGlobalShare(address[] memory _addressPath, uint256 _amount) public view returns(uint256) {
		return getShareAmountPath(_addressPath, _amount);
	}

	// initially `_addressPathReversed` array contains only the last parent contract
	function getPathToContract(address[] memory _addressPathReversed) public view override returns(address[] memory) {
		if(address(this) != _addressPathReversed[_addressPathReversed.length - 1] && parentContract != address(0)) {
			address[] memory bufferArray = new address[](_addressPathReversed.length + 1); 

			// restory initial array
			for (uint256 i = _addressPathReversed.length; i >= 1; i--) {
				bufferArray[i] = _addressPathReversed[i - 1];
			}

			bufferArray[0] = address(this);
			return FERC20(parentContract).getPathToContract(bufferArray);
		} else if(address(this) == _addressPathReversed[_addressPathReversed.length - 1] ) {
			return _addressPathReversed;
		} else {
			return new address[](0);
		}
	}

	function getShareAmountPath(address[] memory _addressPath, uint256 _amount) public view override returns(uint256){
		// todo: add checkup for amount
		if(_addressPath.length > 1) {
			if(_addressPath[1] == address(this) && childContracts.length == 0 &&  _addressPath.length == 2) {
				return getMemberAmountShare(_addressPath[0], _amount);
			} else if (_addressPath[_addressPath.length - 1] != address(this)) {
				if(parentContract != address(0)) {
					return IFERC20(parentContract).getShareAmountPath(_addressPath, _amount);
				} else {
					return 1;
				}
			} else if(_addressPath[_addressPath.length - 1] == address(this)) {	
				return (
					IFERC20(_addressPath[_addressPath.length - 2]).getShareAmountPath(_arrayPopClone(_addressPath), _amount)
					*
					getChildContractShare(_addressPath[_addressPath.length - 2])
				);
			}
		} else {
			// todo: check if no child contracts
			return getMemberAmountShare(_addressPath[0], _amount);
		}
	}

	function getShareBalancePath(address[] memory _addressPath) public view override returns(uint256){
		//todo: add checks
		return getShareAmountPath(
			_addressPath,
			IERC20(_addressPath[1]).balanceOf(_addressPath[0])
		);
		/*
			if(_addressPath.length > 1) {
				if(_addressPath[1] == address(this) && childContracts.length == 0 &&  _addressPath.length == 2) {
					return getMemberShare(_addressPath[0]);
				} else if (_addressPath[_addressPath.length - 1] != address(this)) {
					if(parentContract != address(0)) {
						return IFERC20(parentContract).getShareBalancePath(_addressPath);
					} else {
						return 1;
					}
				} else if(_addressPath[_addressPath.length - 1] == address(this)) {	
					return (
						IFERC20(_addressPath[_addressPath.length - 2]).getShareBalancePath(_arrayPopClone(_addressPath))
						*
						getChildContractShare(_addressPath[_addressPath.length - 2])
					);
				}
			} else {
				// todo: check if no child contracts
				return getMemberShare(_addressPath[0]);
			}
		*/

		// if [1] = address(this):
			//checkIfAccountMember(0)
		// if n - 1 NOT equal to address(this):
			// call parent function with same args
		// if n - 1 equal to address(this):
			// pop last element and call checkPath(n[].pop())
	}

	function getChildContractShare(address _contract) public view returns(uint256){
		require(getChildContractIndex(_contract) != 0, ""); //No such child contract

		uint256[] memory childContractsBalances = new uint256[](childContracts.length);
		for(uint256 i = 0; i < childContracts.length; i++) {
			childContractsBalances[i] = childContracts[i].value;
		}
		return _getShare(
			childContracts[getChildContractIndex(_contract) - 1].value,
			childContractsBalances
		);
	}

	function getMemberAmountShare(address _account, uint256 _amount) public view returns(uint256){
		uint256[] memory membersBalances = new uint256[](members.length);
		for(uint256 i = 0; i < members.length; i++) {
			membersBalances[i] = balanceOf(members[i].memberAddress);
		}
		return _getShare(
			_amount,
			membersBalances
		);
	}

	function getMemberShare(address _account) public view returns(uint256){
		return getMemberAmountShare(_account, balanceOf(_account));
		/*
		uint256[] memory membersBalances = new uint256[](members.length);
		for(uint256 i = 0; i < members.length; i++) {
			membersBalances[i] = balanceOf(members[i].memberAddress);
		}
		return _getShare(
			balanceOf(_account),
			membersBalances
		);
		*/
	}

	function _getShare(uint256 _value, uint256[] memory _allShares) private view returns(uint256) {
		uint256 totalValue = 0;
		for(uint256 i = 0; i < _allShares.length; i++) {
			totalValue += _allShares[i];
		}
		return _value * precision / totalValue; // value in percents
	}

	function _arrayPopClone(address[] memory _arrayToClone) public pure returns(address[] memory) {
		address[] memory newArray = new address[](_arrayToClone.length - 1);
		for(uint256 i = 0; i < _arrayToClone.length - 1; i++) {
			newArray[i] = _arrayToClone[i];
		}
		return newArray;
	}

	function checkIfAccountIsDelegatedFromChildContract(address _account) public view returns(bool) {
		if(childContracts.length > 0) {
			for(uint256 i = 0; i < childContracts.length; i++) {
				uint256 childContractMemberIndex = IFERC20(childContracts[i].childContract).getMemberIndex(_account);
				if(childContractMemberIndex != 0) {
					if(
						IFERC20(childContracts[i].childContract).getAllMembers()[childContractMemberIndex - 1].memberType == MemberType.Delegate
					) return true;
				}
			}
			return false;
		} else false;
	}

	function getNumberOfSupporters(uint256 _votingId) public view returns(uint256) {
		return voteSupported[_votingId].length;
	}

	function getNumberOfAgainst(uint256 _votingId) public view returns(uint256) {
		return voteAgainst[_votingId].length;
	}

	function getMemberIndex(address _account) public view override returns(uint256) {
		for (uint256 i = 1 ; i <= members.length; i++) {
			if (members[i-1].memberAddress == _account) {
				return i;
			}
		}
		return 0;
	}
	
	function getChildContractIndex(address _contractAddress) public view override returns(uint256) {
		for (uint256 i = 1 ; i <= childContracts.length; i++) {
			if (childContracts[i-1].childContract == _contractAddress) {
				return i;
			}
		}
		return 0;
	}

	function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
		require(checkIfAccountMember(from) && checkIfAccountMember(to) || address(0) == from, ""); //Transactions only for members
	}

	function isContract(address _addr) private view returns (bool isContract){
		uint32 size;
		assembly {
			size := extcodesize(_addr)
		}
		return (size > 0);
	}

	function getAllMembers() public view override returns(Member[] memory) {
		return members;
	}

	function getAllChildContracts() public view override returns(ChildContract[] memory) {
		return childContracts;
	}
}
