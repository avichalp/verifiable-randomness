// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract Lottery is VRFConsumerBase, Ownable {

    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }

    LOTTERY_STATE public lottery_state;

    address[] public players;

    uint256 public usdEntryFee;
    AggregatorV3Interface internal _ethUsdPriceFeed;
    uint256 public fee;
    bytes32 public keyHash;
    address payable public recentWinner;
    uint256 public randomness;
    address public link;
    address public vrfCoordinator;

    event RequestedRandomness(bytes32 requestId);
    
    constructor(
        address _priceFeedAddress,
        address _vrfCoordinator,
        address _link,
        uint256 _fee,
        bytes32 _keyHash
        ) VRFConsumerBase(_vrfCoordinator, _link) {
        usdEntryFee = 50  * 10 * (10**18);
        _ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        lottery_state = LOTTERY_STATE.CLOSED;
        vrfCoordinator = _vrfCoordinator;
        link = _link;
        fee = _fee;
        keyHash = _keyHash;
    }
    
    function startLottery() public onlyOwner {
        require(lottery_state == LOTTERY_STATE.CLOSED, "can't start the lottery yet!");
        lottery_state = LOTTERY_STATE.OPEN; 
    }

    function enter() public payable {
        require(msg.value >= getEntranceFee(), "Not enough ETH");
        require(lottery_state == LOTTERY_STATE.OPEN, "Can't enter the new lottery yet!");
        players.push(msg.sender);
    }

    function endLottery() public onlyOwner {
        require(lottery_state == LOTTERY_STATE.OPEN, "Lottery is not open yet");
        require(LINK.balanceOf(address(this)) >= fee,  "Not enough link tokens");

        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
        bytes32 requestId = requestRandomness(keyHash, fee);
        emit RequestedRandomness(requestId);
    }

    function getEntranceFee() public view returns (uint256) {
        (, int price, , , ) = _ethUsdPriceFeed.latestRoundData();
        uint256 adjustedPrice = uint256(price) * 10**10; // 18 decimals
        uint256 costToEnter = (usdEntryFee * 10**18) / adjustedPrice;
        return costToEnter;
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomness) internal override {
            require(lottery_state == LOTTERY_STATE.CALCULATING_WINNER, "You ain't there yet");
            require(_randomness > 0,   "random not found");

            uint playersCount = players.length;
            require(playersCount > 0, "No players in the Lottery");

            uint256 indexOfWinner = _randomness % playersCount;
            recentWinner = payable(players[indexOfWinner]);
            recentWinner.transfer(address(this).balance);
            players = new address payable[](0);
            lottery_state = LOTTERY_STATE.CLOSED;
            randomness = _randomness;

    }
    
}

