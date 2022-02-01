//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./AccountsStorage.sol";

/// @title storage for the smart contract polls
/// @notice stores the polls data and implements getters and setters
/// @author u/AllwaysBuyCheap
contract PollStorage is Ownable {

    AccountsStorage accountsStorage;

    constructor(address _accountsStorageAddress) Ownable() {
        accountsStorage = AccountsStorage(_accountsStorageAddress);
    }

    struct Poll {
        uint128 totalAmountContributed;
        uint32 oracleId;
        uint32 dateLimit;
        uint32 receiverId;
        bool oracleResolved;
        bool oracleResult;
        bool disputed;
        bool ultimateOracleResolved;
        bool ultimateOracleResult;
        bool receiverRewardRequested;
        bool oracleRewardRequested;
    }

    /**
        This struct would be used to store the data of 
        each individual contribution

        @param hasRequested in case the poll is not fullfilled by 
        the creator, this variable indicates if the contributor
        has requested his contribution
     */
    struct PollContributionData {
        uint128 amountContributed;
        bool hasRequested;
    }

    Poll[] public polls;
    mapping (uint => mapping(address => PollContributionData)) public pollsUsersContributions;
    mapping (uint => string) public pollsRequirementsIPFSHashes;

    function getPollsLength() external view returns(uint) {
        return polls.length;
    }
}
