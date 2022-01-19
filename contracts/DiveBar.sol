// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./libraries/FixidityLib.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";

contract DiveBar is ReentrancyGuard {
    using FixidityLib for *;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    uint256 private _cgid = 0;
    uint256 constant DEFAULT_MIN_DEPOSIT = 0.001 ether;
    uint256 constant DEFAULT_POT = 0 ether;
    uint256 constant DEFAULT_PLAYERS_SIZE = 0;
    uint256 game_timeLimit = 12 hours; // for mainnet

    // Cummulative of the royalties taken from each game + any swept pot, owned by the contract
    int256 royalties = 0;

    struct Player {
        address addr;
        uint256 bet;
        uint256 timestamp;
        FixidityLib.Fraction curveWeight; // relative weight of this player against other winners, undefined until game over
    }

    struct Game {
        uint256 id;
        uint256 timeLimit;
        uint256 minDeposit;
        uint256 pot;
        uint256 playersSize;
        uint256 createdAt;
        uint256 endingAt;
        FixidityLib.Fraction avg;
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

    function _onlyOwner() private view {
        require(msg.sender == owner, "Sender not authorized.");
    }

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    constructor() payable {
        owner = payable(msg.sender);
        // Create a new game
        // Game storage currentGame = games[_cgid];
        games[_cgid].id = _cgid;
        // We want the game to last between 30 minutes and an hour
        // make a decoy contract to mirror this but with time skipping perms
        games[_cgid].timeLimit = game_timeLimit;
        games[_cgid].minDeposit = DEFAULT_MIN_DEPOSIT;
        games[_cgid].pot = DEFAULT_POT;
        games[_cgid].avg = FixidityLib.newFixed(0);
        games[_cgid].playersSize = DEFAULT_PLAYERS_SIZE;
        games[_cgid].createdAt = block.timestamp;
        games[_cgid].endingAt = block.timestamp + games[_cgid].timeLimit;
    }

    // ----- Priviledged functions -----

    function getRoyalties() public view onlyOwner returns (int256) {
        return royalties;
    }

    function withdraw(uint256 _amount) public onlyOwner {
        SignedSafeMath.sub(royalties, int256(_amount));
        payable(msg.sender).transfer(_amount);
        emit Withdraw(msg.sender, _amount);
        return;
    }

    function adminSetTime(uint256 _time) public onlyOwner {
        game_timeLimit = _time;
    }

    function adminCallHandleGameOver() public onlyOwner {
        handleGameOver();
    }

    // Contract destructor
    function destroy() public onlyOwner {
        selfdestruct(owner);
    }

    // ---- Receive & Fallback ----

    receive() external payable {
        require(
            msg.value >= games[_cgid].minDeposit,
            "Deposit must be greater than or equal to the minimum deposit"
        );
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
            curveWeight: FixidityLib.newFixed(0),
            timestamp: block.timestamp
        });
        games[_cgid].existingPlayers[msg.sender] = games[_cgid].playersSize + 1;
        games[_cgid].playersSize += 1;
        // Add deposit to the pot
        games[_cgid].pot += msg.value;
        // Calculate the new average
        games[_cgid].avg = FixidityLib.divide(
            FixidityLib.wrap(games[_cgid].pot),
            FixidityLib.newFixed(games[_cgid].playersSize)
        );
        // emit Deposit event
        emit Deposit(msg.sender, msg.value);
    }

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    // ---- Public functions ----

    // Should this be external or public?
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function secondsRemaining() internal view returns (uint256) {
        if (games[_cgid].endingAt <= block.timestamp) {
            return 0; // already there
        } else {
            return games[_cgid].endingAt - block.timestamp;
        }
    }

    function getGameInfo()
        external
        view
        returns (
            uint256 id,
            uint256 timeLimit,
            uint256 minDeposit,
            uint256 pot,
            uint256 playersSize,
            uint256 createdAt,
            uint256 endingAt,
            FixidityLib.Fraction memory avg
        )
    {
        return (
            games[_cgid].id,
            games[_cgid].timeLimit,
            games[_cgid].minDeposit,
            games[_cgid].pot,
            games[_cgid].playersSize,
            games[_cgid].createdAt,
            games[_cgid].endingAt,
            games[_cgid].avg
        );
    }

    function getPlayer(address _addr)
        external
        view
        returns (uint256 bet, uint256 timestamp)
    {
        require(
            games[_cgid].existingPlayers[_addr] != 0,
            "Player is not in the game"
        );
        return (
            games[_cgid].players[games[_cgid].existingPlayers[_addr]].bet,
            games[_cgid].players[games[_cgid].existingPlayers[_addr]].timestamp
        );
    }

    function getUserBalance(address _addr) external view returns (uint256) {
        return balances[_addr];
    }

    // TODO: add custom amount feature
    function getPayout() external payable {
        require(balances[msg.sender] > 0, "You have no winnings");
        // prevent reentrancy
        sendViaCall(payable(msg.sender), balances[msg.sender]);
        balances[msg.sender] = 0;
        return;
    }

    function normalizedTimePenaltyCurve(FixidityLib.Fraction memory idx)
        internal
        pure
        returns (FixidityLib.Fraction memory)
    {
        require(
            idx.value >= 0 && FixidityLib.lte(idx, FixidityLib.fixed1()),
            "Index out of bounds"
        );

        FixidityLib.Fraction memory temp = FixidityLib.multiply(
            FixidityLib.multiply(idx, idx),
            idx
        );

        return FixidityLib.subtract(FixidityLib.fixed1(), temp);
    }

    function calculatePlayerAbsWeight(uint256 playerIdx)
        internal
        returns (FixidityLib.Fraction memory)
    {
        require(
            playerIdx >= 1 && playerIdx <= games[_cgid].playersSize,
            "Player index out of bounds"
        );
        FixidityLib.Fraction memory fixedPlayerRelativeIdx = FixidityLib
            .newFixedFraction(playerIdx, games[_cgid].playersSize);

        FixidityLib.Fraction
            memory fixedPlayerRelativeCurveWeight = normalizedTimePenaltyCurve(
                fixedPlayerRelativeIdx
            );

        games[_cgid]
            .players[playerIdx]
            .curveWeight = fixedPlayerRelativeCurveWeight;
        return fixedPlayerRelativeCurveWeight;
    }

    function handleGameOver() internal {
        require(secondsRemaining() == 0, "Game is not over yet");
        if (games[_cgid].playersSize != 0) {
            payoutWinnings();
        }
        // create a new game
        _cgid += 1;
        // Game storage currentGame = games[_cgid];
        games[_cgid].id = _cgid;
        games[_cgid].timeLimit = game_timeLimit;
        games[_cgid].minDeposit = DEFAULT_MIN_DEPOSIT;
        games[_cgid].pot = DEFAULT_POT;
        games[_cgid].avg = FixidityLib.newFixed(0);
        games[_cgid].playersSize = DEFAULT_PLAYERS_SIZE;
        games[_cgid].createdAt = block.timestamp;
        games[_cgid].endingAt = block.timestamp + games[_cgid].timeLimit;
        return;
    }

    function payoutWinnings() internal {
        // Calculate number of losers
        uint256 numLosers = 0;
        uint256 numWinners = 0;
        FixidityLib.Fraction memory winnersAbsWeightSum = FixidityLib.newFixed(
            0
        );
        uint256 losersPot = 0;
        for (uint256 i = 1; i <= games[_cgid].playersSize; i++) {
            if (
                FixidityLib.lt(
                    FixidityLib.wrap(games[_cgid].players[i].bet),
                    games[_cgid].avg
                )
            ) {
                numLosers += 1;
                losersPot += games[_cgid].players[i].bet;
            } else {
                winnersAbsWeightSum = FixidityLib.add(
                    winnersAbsWeightSum,
                    calculatePlayerAbsWeight(i)
                );
            }
        }

        numWinners = games[_cgid].playersSize - numLosers;
        if (numWinners == 0) {
            return;
        }

        for (uint256 i = 1; i <= games[_cgid].playersSize; i++) {
            if (
                FixidityLib.gte(
                    FixidityLib.wrap(games[_cgid].players[i].bet),
                    games[_cgid].avg
                )
            ) {
                uint256 additionalWinnings = 0;
                FixidityLib.Fraction memory computedWeight = FixidityLib
                    .newFixed(0);
                // If only one winner who is last player, do they get any of the losers pot?
                if (FixidityLib.unwrap(winnersAbsWeightSum) != 0) {
                    computedWeight = FixidityLib.newFixedFraction(
                        FixidityLib.unwrap(games[_cgid].players[i].curveWeight),
                        FixidityLib.unwrap(winnersAbsWeightSum)
                    );
                }
                if (losersPot != 0) {
                    additionalWinnings = FixidityLib.unwrap(
                        FixidityLib.multiply(
                            FixidityLib.multiply(
                                FixidityLib.wrap(losersPot),
                                computedWeight
                            ),
                            // TODO: platform fee should be taken out either the total pot or every payout, i think they are equivalent though
                            FixidityLib.newFixedFraction(99, 100) // Platform fee of 1%
                        )
                    );
                }

                uint256 payout = games[_cgid].players[i].bet +
                    additionalWinnings;
                // Update player's balance
                balances[games[_cgid].players[i].addr] += payout;
                // subtract payout from pot
                games[_cgid].pot -= payout;
                // emit Payout event
                emit Payout(games[_cgid].players[i].addr, payout);
            }
        }
        if (games[_cgid].pot > 0) {
            SignedSafeMath.add(royalties, int256(games[_cgid].pot));
            emit Payout(owner, games[_cgid].pot);
            games[_cgid].pot = 0;
        }

        delete numLosers;
        delete numWinners;
        delete winnersAbsWeightSum;
        delete losersPot;
        return;
    }

    function sendViaCall(address payable _to, uint256 payout) internal {
        (bool sent,) = _to.call{value: payout}("");
        require(sent, "Failed to send Ether");
        return;
    }
}
