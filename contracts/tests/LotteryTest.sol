
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../Lottrey.sol";

import "hardhat/console.sol";


contract LotteryTest is Lottery {

    // todo using SafeMath ??

    constructor(
        address _priceFeedAddress,
        address _vrfCoordinator,
        address _link,
        uint256 _fee,
        bytes32 _keyHash
    )
    Lottery(
        _priceFeedAddress,
        _vrfCoordinator,            
        _link,
        _fee,
        _keyHash
    )
    {
    }

    function testFulfillRandomnessNotStarted(bytes32 requestId, uint256 _randomness) public {
            Lottery.fulfillRandomness(requestId, _randomness);
    }
    
    function testFulfillRandomnessZeroRandomness(bytes32 requestId, uint256 _randomness) public {
            Lottery.lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
            Lottery.fulfillRandomness(requestId, _randomness);
    }

    function testFulfillRandomnessZeroPlayers(bytes32 requestId, uint256 _randomness) public {
            Lottery.lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
            Lottery.fulfillRandomness(requestId, _randomness);
    }

    function testFulfillRandomnessSuccess(bytes32 requestId, uint256 _randomness) public payable {
            Lottery.lottery_state = LOTTERY_STATE.OPEN;
            Lottery.enter();
            
            uint256 senderBalanceBefore = msg.sender.balance;

            Lottery.lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
            Lottery.fulfillRandomness(requestId, _randomness);

            uint256 senderBalanceAfter = msg.sender.balance;

            require(Lottery.recentWinner == msg.sender, "Winner is not correct");            
            require((senderBalanceAfter - senderBalanceBefore) == msg.value, "Incorrect amount transfered to the winner");
            require(Lottery.players.length == 0, "Players array is not set to empty after lottery ends");
            require(Lottery.lottery_state == LOTTERY_STATE.CLOSED, "Lottery didn't close");
            require(Lottery.randomness == randomness, "Randomness is not correct");            
    }

}


