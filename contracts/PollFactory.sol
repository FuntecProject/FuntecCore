//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./PollStorage.sol";

/// @title high level contract to interact with the polls
/// @notice implements create and contribute functions
/// @author u/AllwaysBuyCheap
contract PollFactory is PollStorage {    

    constructor (address _accountsStorageAddress) PollStorage(_accountsStorageAddress) payable {
    }

    event contribution(
        address contributor, 
        uint pollId,
        uint amountContributed
    );

    event pollCreation(
        uint pollId, 
        uint indexed receiverId, 
        uint indexed oracleId, 
        uint dateLimit,
        uint amountContributed,
        address contributor,
        string _hash
    );

    /// @notice creates a new poll
    /// @param _receiverId the account that its going to receive the reward
    /// @param _dateLimit the date limit until its possible to contribute
    function createPoll(
        uint _receiverId,
        uint32 _dateLimit,
        uint _oracleId,
        string memory _hash
    ) external payable {
        require(_dateLimit > block.timestamp, "DateLimit bigger than timestamp");
        require(_receiverId < accountsStorage.getReceiversLength(), "Receiver must have account");
        require(accountsStorage.isOracleEnabled(_oracleId), "Oracle must be enabled");

        pollsUsersContributions[polls.length][msg.sender].amountContributed += uint128(msg.value);
        pollsRequirementsIPFSHashes[polls.length] = _hash;
        polls.push(Poll(uint128(msg.value), uint32(_oracleId), _dateLimit, uint32(_receiverId), false, false, false, false, false, false, false));

        emit pollCreation(polls.length - 1, _receiverId, _oracleId, _dateLimit, msg.value, msg.sender, _hash);
        emit contribution(msg.sender, polls.length - 1, msg.value);
    }

    /// @notice contributes to an already existing poll
    /// @param _pollId the poll to be contributed
    function contribute(uint _pollId) external payable {
        require(_pollId < polls.length, "Poll must exist");
        require(block.timestamp < polls[_pollId].dateLimit, "Date must be before limit");

        pollsUsersContributions[_pollId][msg.sender].amountContributed += uint128(msg.value);
        polls[_pollId].totalAmountContributed += uint128(msg.value);

        emit contribution(msg.sender, _pollId, msg.value);
    }
}