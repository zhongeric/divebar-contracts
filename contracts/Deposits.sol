// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

// import "./libraries/IterableMapping.sol";

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Deposits is ReentrancyGuard {
    using SafeMath for uint256;

    uint256 public constant DEFAULT_MIN_DEPOSIT = 0.001 ether;
    uint256 public constant DEFAULT_POT = 0 ether;
    uint256 public constant DEFAULT_AVG = 0 ether;
    uint256 public constant DEFAULT_PLAYERS_SIZE = 0;

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

    mapping(uint256 => Game) games;
    uint256 private _cgid = 0;

    constructor() payable {
        owner = payable(msg.sender);
        // Create a new game
        Game storage currentGame = games[_cgid];
        currentGame.id = _cgid;
        currentGame.timeLimit = 5 seconds;
        currentGame.minDeposit = DEFAULT_MIN_DEPOSIT;
        currentGame.pot = DEFAULT_POT;
        currentGame.avg = DEFAULT_AVG;
        currentGame.playersSize = DEFAULT_PLAYERS_SIZE;
        currentGame.createdAt = block.timestamp;
        currentGame.endingAt = block.timestamp + currentGame.timeLimit;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {
        require(
            msg.value >= games[_cgid].minDeposit,
            "Deposit must be greater than or equal to the minimum deposit"
        );
        // all players are new to the game, can only enter once
        // continue only if the player is not in the game already
        require(
            games[_cgid].existingPlayers[msg.sender] == 0,
            "You are already in the game"
        );
        // make sure the game is not over
        require(games[_cgid].endingAt > block.timestamp, "The game has ended");

        // First real player at 1, so non existent players are 0
        games[_cgid].players[games[_cgid].playersSize + 1] = Player({
            addr: msg.sender,
            bet: msg.value,
            winnings: 0,
            timestamp: block.timestamp
        });
        games[_cgid].existingPlayers[msg.sender] = games[_cgid].playersSize + 1;
        games[_cgid].playersSize += 1;
        // Add deposit to the pot
        games[_cgid].pot += msg.value;
        // Calculate the new average
        games[_cgid].avg = games[_cgid].pot / games[_cgid].playersSize;
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
        if (games[_cgid].endingAt <= block.timestamp) {
            return 0; // already there
        } else {
            return games[_cgid].endingAt - block.timestamp;
        }
    }

    // Function to return currentGame info
    function getGameInfo()
        public
        view
        returns (
            uint256 id,
            uint256 timeLimit,
            uint256 minDeposit,
            uint256 pot,
            uint256 avg,
            uint256 playersSize,
            uint256 createdAt,
            uint256 endingAt
        )
    {
        return (
            games[_cgid].id,
            games[_cgid].timeLimit,
            games[_cgid].minDeposit,
            games[_cgid].pot,
            games[_cgid].avg,
            games[_cgid].playersSize,
            games[_cgid].createdAt,
            games[_cgid].endingAt
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
        _cgid += 1;
        Game storage currentGame = games[_cgid];
        currentGame.id = _cgid;
        currentGame.timeLimit = 5 seconds;
        currentGame.minDeposit = DEFAULT_MIN_DEPOSIT;
        currentGame.pot = DEFAULT_POT;
        currentGame.avg = DEFAULT_AVG;
        currentGame.playersSize = DEFAULT_PLAYERS_SIZE;
        currentGame.createdAt = block.timestamp;
        currentGame.endingAt = block.timestamp + currentGame.timeLimit;
    }

    function payoutWinnings() private {
        // Iterate through players
        for (uint256 i = 1; i <= games[_cgid].playersSize; i++) {
            // send winnings to player

            sendViaCall(payable(games[_cgid].players[i].addr));
            // subtract winnings from pot
            games[_cgid].pot -= msg.value;
            // emit Payout event
            emit Payout(games[_cgid].players[i].addr, msg.value);
            console.log("Payout sent to: ", games[_cgid].players[i].addr);
        }
    }

    function sendViaCall(address payable _to) internal {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.
        (bool sent, bytes memory data) = _to.call{value: msg.value}("");
        require(sent, "Failed to send Ether");
    }
}
