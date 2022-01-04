// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

// import "./libraries/IterableMapping.sol";

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Deposits is ReentrancyGuard {
    using SafeMath for uint256;

    struct Player {
        address player;
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
        mapping(address => Player) players;
        uint256 playersSize;
        uint256 createdAt;
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
        currentGame.timeLimit = 60;
        currentGame.minDeposit = 0.0001 ether;
        currentGame.pot = 0 ether;
        currentGame.avg = 0 ether;
        currentGame.createdAt = block.timestamp;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {
        require(msg.value >= currentGame.minDeposit);
        // Add deposit to the pot
        currentGame.pot += msg.value;
        console.log("Msg.value: ", msg.value);
        console.log("Pot: ", currentGame.pot);
        // Add player to the currentGame
        // I assume any sender is initialized to 0
        if (currentGame.players[msg.sender].bet == 0) {
            currentGame.players[msg.sender] = Player({
                player: msg.sender,
                bet: msg.value,
                winnings: 0,
                timestamp: block.timestamp
            });
        }
        currentGame.players[msg.sender].bet += msg.value;
        // emit Deposit event
        emit Deposit(msg.sender, msg.value);
    }

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    // Should this be external or public?
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Function to return currentGame info
    function getGamePot() public view returns (uint256) {
        return currentGame.pot;
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == owner, "caller is not owner");
        payable(msg.sender).transfer(_amount);
    }

    function sendViaCall(address payable _to) public payable {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.
        (bool sent, bytes memory data) = _to.call{value: msg.value}("");
        require(sent, "Failed to send Ether");
    }
}
