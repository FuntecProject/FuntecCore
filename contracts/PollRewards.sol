//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./PollActions.sol";

contract PollRewards is PollActions {

    constructor (address _accountsStorageAddress) PollActions(_accountsStorageAddress) {
    }

    event receiverRewardRequested(
        uint pollId
    );

    event oracleRewardRequested(
        uint pollId
    );

    event contributionRequested(
        address contributor,
        uint pollId
    );

    event pollNotResolvedOrDisputed(
        uint pollId
    );

    function claimContribution(uint _pollId) external {
        require(polls[_pollId].dateLimit + accountsStorage.getOracleResponseTime(polls[_pollId].oracleId) + 24 * 60 * 60 < block.timestamp, "Dispute time must have passed");
        require(pollsUsersContributions[_pollId][msg.sender].hasRequested == false, "Contribution must not be requested");

        pollsUsersContributions[_pollId][msg.sender].hasRequested = true;

        if (polls[_pollId].oracleResolved) {
            if (polls[_pollId].disputed == false) {
                if (polls[_pollId].oracleResult == false) {
                    Address.sendValue(
                        payable(msg.sender), 
                        calculateReward(
                            pollsUsersContributions[_pollId][msg.sender].amountContributed, 
                            calculateOracleFeePercent(
                                accountsStorage.getOracleFee(polls[_pollId].oracleId) * 10**9, 
                                polls[_pollId].totalAmountContributed
                            )
                        )
                    );
                }
            } 

            else {
                if (polls[_pollId].ultimateOracleResolved) {
                    if (polls[_pollId].ultimateOracleResult == false) {
                        if (polls[_pollId].oracleResult == polls[_pollId].ultimateOracleResult) {
                            Address.sendValue(
                                payable(msg.sender), 
                                calculateReward(
                                    pollsUsersContributions[_pollId][msg.sender].amountContributed, 
                                    calculateOracleFeePercent(
                                        accountsStorage.getOracleFee(polls[_pollId].oracleId) * 10**9, 
                                        polls[_pollId].totalAmountContributed
                                    )
                                )
                            );
                        }           
                        else {
                            Address.sendValue(
                                payable(msg.sender), 
                                pollsUsersContributions[_pollId][msg.sender].amountContributed
                            );
                        }
                    } 
                }
            }

        }

        else {
            if (polls[_pollId].disputed == false) {
                Address.sendValue(
                    payable(msg.sender), 
                    pollsUsersContributions[_pollId][msg.sender].amountContributed
                );

                emit pollNotResolvedOrDisputed(_pollId);
            }

            else {
                if (polls[_pollId].ultimateOracleResolved) {
                    if (polls[_pollId].ultimateOracleResult == false) {
                        Address.sendValue(
                            payable(msg.sender), 
                            pollsUsersContributions[_pollId][msg.sender].amountContributed
                        );
                    }
                }
            }
        }

        emit contributionRequested(msg.sender, _pollId);
    }

    function claimReceiverReward(uint _pollId) external {
        require(polls[_pollId].dateLimit + accountsStorage.getOracleResponseTime(polls[_pollId].oracleId) + 24 * 60 * 60 < block.timestamp, "Dispute time must have passed");
        require(polls[_pollId].receiverRewardRequested == false, "Receiver reward must not be requested");

        polls[_pollId].receiverRewardRequested = true;

        if (polls[_pollId].oracleResolved) {
            if (polls[_pollId].disputed == false) {
                if (polls[_pollId].oracleResult) {
                    Address.sendValue(
                        payable(accountsStorage.receivers(polls[_pollId].receiverId)), 
                        calculateReward(
                            polls[_pollId].totalAmountContributed, 
                            calculateOracleFeePercent(
                                accountsStorage.getOracleFee(polls[_pollId].oracleId) * 10**9, 
                                polls[_pollId].totalAmountContributed)
                        )
                    );
                }
            }           
            
            else {
                if (polls[_pollId].ultimateOracleResolved) {
                    if (polls[_pollId].ultimateOracleResult) {
                        if (polls[_pollId].ultimateOracleResult == polls[_pollId].oracleResult) {
                            Address.sendValue(
                                payable(accountsStorage.receivers(polls[_pollId].receiverId)), 
                                calculateReward(
                                    polls[_pollId].totalAmountContributed, 
                                    calculateOracleFeePercent(
                                        accountsStorage.getOracleFee(polls[_pollId].oracleId) * 10**9, 
                                        polls[_pollId].totalAmountContributed)
                                )
                            );
                        }           
                        else {
                            Address.sendValue(
                                payable(accountsStorage.receivers(polls[_pollId].receiverId)), 
                                polls[_pollId].totalAmountContributed
                            );
                        }
                    }
                }
            }
        }

        else {
            if (polls[_pollId].disputed) {
                if (polls[_pollId].ultimateOracleResult) {
                    Address.sendValue(
                        payable(accountsStorage.receivers(polls[_pollId].receiverId)), 
                        polls[_pollId].totalAmountContributed
                    );
                }
            }
        }

        emit receiverRewardRequested(_pollId);
    }

    function claimOracleReward(uint _pollId) external {
        require(polls[_pollId].oracleRewardRequested == false, "Oracle must not be requested");
        require(polls[_pollId].oracleResolved, "Oracle must have resolved");

        polls[_pollId].oracleRewardRequested = true;

        if (polls[_pollId].disputed == true) {
            require(polls[_pollId].ultimateOracleResolved == true, "Dispute must be resolved");
            require(polls[_pollId].oracleResult == polls[_pollId].ultimateOracleResult, "Dispute result must match result");
        }

        else {
            require((polls[_pollId].dateLimit + accountsStorage.getOracleResponseTime(polls[_pollId].oracleId) + 86400) < block.timestamp, "Dispute period must have passed");
        }

        /**
            Oracle fee percent should be more clear
         */
        Address.sendValue(
            payable(accountsStorage.getOracleAddress(polls[_pollId].oracleId)), 
            polls[_pollId].totalAmountContributed * calculateOracleFeePercent(accountsStorage.getOracleFee(polls[_pollId].oracleId) * 10**9, polls[_pollId].totalAmountContributed) / 10000
        );

        emit oracleRewardRequested(_pollId);
    }

    function calculateOracleFeePercent (
        uint _oracleFee,
        uint _totalAmountContributed
    ) private pure returns(uint) {
        return ((10000 * _oracleFee) / _totalAmountContributed) + 1;
    }

    function calculateReward(
        uint _totalAmountContributed,
        uint _substract
    ) private pure returns(uint) {
        return (_totalAmountContributed * (10000 - _substract)) / 10000;
    }
}