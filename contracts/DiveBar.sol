// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

// TODO: variable packing (uint8 for uint256 in some structs)

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DiveBar is ReentrancyGuard {
    using SafeMath for uint256;

    uint256 private _cgid = 0;
    uint256 public constant DEFAULT_MIN_DEPOSIT = 0.001 ether;
    uint256 public constant DEFAULT_POT = 0 ether;
    uint256 public constant DEFAULT_AVG = 0 ether;
    uint256 public constant DEFAULT_PLAYERS_SIZE = 0;

    struct Player {
        address addr;
        uint256 bet;
        uint256 timestamp;
    }

    struct Game {
        uint256 id;
        uint256 timeLimit;
        uint256 minDeposit;
        uint256 pot;
        uint256 avg;
        uint256 playersSize;
        uint256 createdAt;
        uint256 endingAt;
        // array of players
        mapping(uint256 => Player) players;
        mapping(address => uint256) existingPlayers;
    }

    address payable public owner;
    event Deposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed sender, uint256 amount);
    event Payout(address indexed receiver, uint256 amount);

    mapping(address => uint256) private balances;
    mapping(uint256 => Game) games;

    constructor() payable {
        owner = payable(msg.sender);
        // Create a new game
        // Game storage currentGame = games[_cgid];
        games[_cgid].id = _cgid;
        // We want the game to last between 30 minutes and an hour
        // make a decoy contract to mirror this but with time skipping perms
        games[_cgid].timeLimit = 30 seconds;
        games[_cgid].minDeposit = DEFAULT_MIN_DEPOSIT;
        games[_cgid].pot = DEFAULT_POT;
        games[_cgid].avg = DEFAULT_AVG;
        games[_cgid].playersSize = DEFAULT_PLAYERS_SIZE;
        games[_cgid].createdAt = block.timestamp;
        games[_cgid].endingAt = block.timestamp + games[_cgid].timeLimit;
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
        external
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
        emit Withdraw(msg.sender, _amount);
        return;
    }

    // TODO: add custom amount feature
    function getPayout() external payable {
        require(balances[msg.sender] > 0, "You have no winnings");
        sendViaCall(payable(msg.sender), balances[msg.sender]);
        return;
    }

    function handleGameOver() external {
        require(secondsRemaining() == 0, "Game is not over yet");
        payoutWinnings();
        // create a new game
        _cgid += 1;
        // Game storage currentGame = games[_cgid];
        games[_cgid].id = _cgid;
        games[_cgid].timeLimit = 30 seconds;
        games[_cgid].minDeposit = DEFAULT_MIN_DEPOSIT;
        games[_cgid].pot = DEFAULT_POT;
        games[_cgid].avg = DEFAULT_AVG;
        games[_cgid].playersSize = DEFAULT_PLAYERS_SIZE;
        games[_cgid].createdAt = block.timestamp;
        games[_cgid].endingAt = block.timestamp + games[_cgid].timeLimit;
        return;
    }

    function payoutWinnings() internal {
        console.log("Paying out winners of game", games[_cgid].id);
        // Calculate number of losers
        uint256 numLosers = 0;
        for (uint256 i = 1; i <= games[_cgid].playersSize; i++) {
            // TODO: do you need to bet more than the average or is equal to okay?
            if (games[_cgid].players[i].bet < games[_cgid].avg) {
                numLosers += 1;
            }
        }
        console.log("numLosers: ", numLosers);
        console.log("numWinners: ", games[_cgid].playersSize - numLosers);
        if (games[_cgid].playersSize - numLosers == 0) {
            console.log("No winners");
            return;
        }
        // Calculate payout per winner
        // TODO: remove this and put operation inline to save on gas?
        uint256 payoutPerWinner = games[_cgid].pot /
            (games[_cgid].playersSize - numLosers);
        console.log("payoutPerWinner: ", payoutPerWinner);

        // Iterate through players
        for (uint256 i = 1; i <= games[_cgid].playersSize; i++) {
            // send payout to player only if bet >= avg
            if (games[_cgid].players[i].bet >= games[_cgid].avg) {
                // Update player's balance
                balances[games[_cgid].players[i].addr] += payoutPerWinner;
                // subtract payout from pot
                games[_cgid].pot -= payoutPerWinner;
                // emit Payout event
                emit Payout(games[_cgid].players[i].addr, payoutPerWinner);
                console.log("Payout sent to: ", games[_cgid].players[i].addr);
            }
        }
        console.log("Pot: ", games[_cgid].pot);
        if (games[_cgid].pot > 0) {
            // TODO: keep remaining funds in contract so do nothing?
            games[_cgid].pot = 0;
            emit Payout(owner, msg.value);
            console.log("Remaining pot swept to: ", owner);
        }

        delete payoutPerWinner;
        delete numLosers;
        return;
    }

    function sendViaCall(address payable _to, uint256 payout) internal {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.
        (bool sent, bytes memory data) = _to.call{value: payout}("");
        require(sent, "Failed to send Ether");
        return;
    }
}
