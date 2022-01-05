// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

// import "./libraries/IterableMapping.sol";

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Deposits is ReentrancyGuard {
    using SafeMath for uint256;

    struct Player {
        address addr;
        uint256 bet;
        uint256 winnings;
        uint256 timestamp; // The timestamp when the user waved.
    }

    struct Game {
        uint256 id;
        uint256 timeLimit;
        uint256 minDeposit;
        uint256 pot;
        uint256 avg;
        // array of players
        mapping(uint256 => Player) players;
        mapping(address => uint256) existingPlayers;
        uint256 playersSize;
        uint256 createdAt;
        uint256 endingAt;
    }

    address payable public owner;
    event Deposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed sender, uint256 amount);
    event Payout(address indexed receiver, uint256 amount);

    Game private currentGame;

    constructor() payable {
        owner = payable(msg.sender);
        // Create a new game
        currentGame.id = 0;
        currentGame.timeLimit = 5;
        currentGame.minDeposit = 0.0001 ether;
        currentGame.pot = 0 ether;
        currentGame.avg = 0 ether;
        currentGame.playersSize = 0;
        currentGame.createdAt = block.timestamp;
        currentGame.endingAt = block.timestamp + currentGame.timeLimit;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {
        require(
            msg.value >= currentGame.minDeposit,
            "Deposit must be greater than or equal to the minimum deposit"
        );
        // all players are new to the game, can only enter once
        // continue only if the player is not in the game already
        require(
            currentGame.existingPlayers[msg.sender] == 0,
            "You are already in the game"
        );
        // make sure the game is not over
        require(currentGame.endingAt > block.timestamp, "The game has ended");

        // First real player at 1, so non existent players are 0
        currentGame.players[currentGame.playersSize + 1] = Player({
            addr: msg.sender,
            bet: msg.value,
            winnings: 0,
            timestamp: block.timestamp
        });
        currentGame.existingPlayers[msg.sender] = currentGame.playersSize + 1;
        currentGame.playersSize += 1;
        // Add deposit to the pot
        currentGame.pot += msg.value;
        console.log("Msg.value: ", msg.value);
        console.log("Pot: ", currentGame.pot);
        // emit Deposit event
        emit Deposit(msg.sender, msg.value);
    }

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    // Should this be external or public?
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function secondsRemaining() public view returns (uint256) {
        if (currentGame.endingAt <= block.timestamp) {
            return 0; // already there
        } else {
            return currentGame.endingAt - block.timestamp;
        }
    }

    // Function to return currentGame info
    function getGameInfo()
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            currentGame.id,
            currentGame.timeLimit,
            currentGame.minDeposit,
            currentGame.pot,
            currentGame.avg,
            currentGame.playersSize,
            currentGame.createdAt,
            currentGame.endingAt
        );
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == owner, "caller is not owner");
        payable(msg.sender).transfer(_amount);
    }

    function handleGameOver() public payable {
        require(secondsRemaining() == 0, "Game is not over yet");
        payoutWinnings();
        // create a new game
        currentGame.id = currentGame.id + 1;
        currentGame.createdAt = block.timestamp;
        currentGame.endingAt = block.timestamp + currentGame.timeLimit;
    }

    function payoutWinnings() private {
        // Iterate through players
        for (uint256 i = 1; i <= currentGame.playersSize; i++) {
            // send winnings to player
            sendViaCall(payable(currentGame.players[i].addr));
            // emit Payout event
            emit Payout(currentGame.players[i].addr, 0.1 ether);
            console.log("Payout sent to: ", currentGame.players[i].addr);
        }
    }

    function sendViaCall(address payable _to) internal {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.
        (bool sent, bytes memory data) = _to.call{value: msg.value}("");
        require(sent, "Failed to send Ether");
    }
}
