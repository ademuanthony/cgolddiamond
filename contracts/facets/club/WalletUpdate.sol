// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author:Ademu Anthony (https://twitter.com/Oxa2e)
/******************************************************************************/

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Club250Base.sol";
import "./LibClub250Storage.sol";
import "../shared/Access/CallProtection.sol";
import "../shared/Reentry/ReentryProtection.sol";
import "../ERC20/LibERC20.sol";
import "hardhat/console.sol";

contract WalletUpdate is Club250Base, CallProtection, ReentryProtection {
    using SafeMath for uint256;

    function changeWalletFor(uint256 userId, address addr) external protectedCall {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        es.userAddresses[userId] = addr;
    }
}
