// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Game is ReentrancyGuard {
    using SafeMath for uint256;

    address public owner;

    constructor() {
        owner = msg.sender;
    }
}
