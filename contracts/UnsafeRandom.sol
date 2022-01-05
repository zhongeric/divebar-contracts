// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract UnsafeRandom is ReentrancyGuard {
    uint256 nonce;

    function _unsafeRandom() internal returns (uint256) {
        // This is psuedo-random, and not to be used for to calculate winnings, etc.
        uint256 random = uint256(
            keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))
        ) % 100;
        nonce++;
        return random;
    }

    function getUnsafeRandom() external returns (uint256) {
        return _unsafeRandom();
    }
}
