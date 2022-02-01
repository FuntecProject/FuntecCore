//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./PollRewards.sol";

contract UltimateOracle is Ownable {
    PollRewards polls;

    constructor (address _dappAddress) Ownable() payable {
        polls = PollRewards(_dappAddress);
    }

    function setDappAddress(address _dappAddress) external onlyOwner {
        polls = PollRewards(_dappAddress);
    }

    function closeDispute(
        uint _pollId,
        bool _result
    ) external onlyOwner {
        polls.closeDispute(_pollId, _result);
    }

    function withdrawFunds(
        address _receiverAddress,
        uint _amount
    ) external onlyOwner {
        Address.sendValue(payable(_receiverAddress), _amount);
    }

    receive() external payable {}
}