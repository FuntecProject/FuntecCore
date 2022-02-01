//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

/**
    TODO

    the contribution should not use 10**9
    the contracts must be well documented specially in those confusing elements like reward claiming,
    don't mind being too explicit this code must be read and understood by a lazy person not involved in the project

    it seems that I forgot to send the reward to the platform in the claiming process, fix the test to check if its working
 */


import "./PollFactory.sol";
// import "hardhat/console.sol";

contract PollActions is PollFactory {

    address payable platformRewardReceiverAddress;
    address ultimateOracleAddress;
    uint ultimateOracleFee;

    event pollResolved(
        uint pollId,
        uint oracleId,
        bool oracleResult
    );

    event pollDisputed(
        uint pollId
    );

    event disputeClosed(
        uint pollId,
        bool disputeResult
    );      

    constructor (address _accountsStorageAddress) PollFactory(_accountsStorageAddress) {
        platformRewardReceiverAddress = payable(msg.sender);
    }

    /**
        This is the method that the oracle must call 
        to decide if the receiver has fullfilled the 
        poll requirement

        It must be done after the poll limit is reached 
        and before the oracle response time is passed
     */
    function resolvePoll(
        bool _result,
        uint _pollId
    ) external {
        uint _oracleId = polls[_pollId].oracleId;

        require(accountsStorage.getOracleAddress(_oracleId) == msg.sender, "Executor must be oracle selected");
        require(
            polls[_pollId].dateLimit < block.timestamp && block.timestamp < polls[_pollId].dateLimit + accountsStorage.getOracleResponseTime(_oracleId), 
            "Dispute timeframe must have passed"
        );
        require(polls[_pollId].oracleResolved == false, "Poll must not be resolved");
        require(polls[_pollId].totalAmountContributed > 4 * accountsStorage.getOracleFee(_oracleId) * 10**9, "The amount contributed must be > 4 * oraclefee");

        polls[_pollId].oracleResolved = true;
        polls[_pollId].oracleResult = _result;

        emit pollResolved(_pollId, _oracleId, _result);
    }

    function generateDispute(uint _pollId) external payable{
        require(msg.value == ultimateOracleFee, "Disputer must pay the fee");
        require(polls[_pollId].disputed == false, "Poll must not be disputed");
        require(
            block.timestamp < polls[_pollId].dateLimit + accountsStorage.getOracleResponseTime(polls[_pollId].oracleId) + 86400, 
            "Dispute timeframe must not been passed"
        );

        Address.sendValue(payable(ultimateOracleAddress), msg.value);
        polls[_pollId].disputed = true;

        emit pollDisputed(_pollId);
    }

    function closeDispute(uint _pollId, bool _result) external {
        require(msg.sender == ultimateOracleAddress, "Only the ultimate oracle can call this function");
        require(polls[_pollId].disputed, "Poll must be disputed");
        require(polls[_pollId].ultimateOracleResolved == false, "Dispute must not been resolved");


        polls[_pollId].ultimateOracleResolved = true;
        polls[_pollId].ultimateOracleResult = _result;

        emit disputeClosed(_pollId, _result);
    }

    /**
        DAO management methods
     */

    function changePlatformOwnerAddress(address _platformOwnerAddress) external onlyOwner {
        platformRewardReceiverAddress = payable(_platformOwnerAddress);
    }

    function setUltimateOracleAddress(address _ultimateOracleAddress) external onlyOwner {
        ultimateOracleAddress = _ultimateOracleAddress;
    }

    function setUltimateOracleFee(uint _ultimateOracleFee) external onlyOwner {
        ultimateOracleFee = _ultimateOracleFee;
    }
}  