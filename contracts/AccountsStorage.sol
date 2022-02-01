//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title storage for the smart contract accounts
/// @notice creates and stores the smart contract accounts
/// @author u/AllwaysBuyCheap
contract AccountsStorage is Ownable {

    struct Oracle {
        address oracleAddress;
		uint32 previousOracleId;
		uint32 oracleFee;
        uint24 responseTime;
		bool enabledOracle;
    }

	address[] public receivers;
	mapping(address => uint) public addressToReceiverId;

	Oracle[] public oracles;
	mapping(address => uint) public addressToOracleId;

	event newOracle(
		uint oracleId,
		uint oracleFee,
		uint oracleResponseTime
	);

	event oracleStatusChanged(
		uint oracleId,
		bool disabledOracle
	);

	event oracleDataChanged(
		uint oracleId,
		uint previousOracleId,
		uint oracleFee,
		uint oracleResponseTime
	);
	
	constructor () Ownable() payable {
		receivers.push(0x0000000000000000000000000000000000000000);
		oracles.push(Oracle(0x0000000000000000000000000000000000000000, 0, 0, 0, false));
	}

	/// @notice creates a new account
	function createReceiverAccount() external {
		require(addressToReceiverId[msg.sender] == 0, "Address must not have account");
		
		addressToReceiverId[msg.sender] = receivers.length;
		receivers.push(msg.sender);
	}

    function createNewOracle(
        uint _responseTime,
		uint _oracleFee
    ) external {
		require(addressToOracleId[msg.sender] == 0, "Address must not have an account");

        addressToOracleId[msg.sender] = oracles.length;
        oracles.push(Oracle(msg.sender, 0, uint32(_oracleFee), uint24(_responseTime), true));
    
		emit newOracle(oracles.length - 1, _oracleFee, _responseTime);
	}

	///TODO test this function
	function changeReceiverAccountAddress(address _newAccountAddress) external {
		uint _id = addressToReceiverId[msg.sender];
		
		require(0 < _id && _id < receivers.length, "The sender must have a valid account");
		
		receivers[_id] = _newAccountAddress;
		addressToReceiverId[_newAccountAddress] = _id;
		addressToReceiverId[msg.sender] = 0;
	}

	/**
		TODO explain why this action does not need to create a new oracle
	 */
	function disableOracle(uint _oracleId, bool _status) external {
		require(addressToOracleId[msg.sender] == _oracleId, "Only the oracle owner can modidy");
		
		oracles[_oracleId].enabledOracle = _status;

		emit oracleStatusChanged(_oracleId, _status);
	}

	/**
		TODO explain why this function is needed
	 */
	function changeOracleResponseTimeAndFee(
		uint _oracleId,
		uint _oracleFee,
		uint _oracleResponseTime
	) external {
		require(addressToOracleId[msg.sender] == _oracleId, "Only the oracle owner can modify");

		addressToOracleId[msg.sender] = oracles.length;
		oracles.push(Oracle(msg.sender, uint32(_oracleId), uint32(_oracleFee), uint24(_oracleResponseTime), false));
	
		emit oracleDataChanged(oracles.length - 1, _oracleId, _oracleFee, _oracleResponseTime);
	}

	/**
		Public getters
	 */
	
	function getOraclesLength() external view returns(uint) {
        return oracles.length;
    }

	function getReceiversLength() external view returns(uint) {
		return receivers.length;
	}

	function getOracleAddress(uint _oracleId) external view returns(address) {
		return oracles[_oracleId].oracleAddress;
	}

	function getOracleFee(uint _oracleId) external view returns(uint) {
		return oracles[_oracleId].oracleFee;
	}

	function getOracleResponseTime(uint _oracleId) external view returns(uint) {
		return oracles[_oracleId].responseTime;
	}

	function isOracleEnabled(uint _oracleId) external view returns(bool) {
		return oracles[_oracleId].enabledOracle;
	}
}
