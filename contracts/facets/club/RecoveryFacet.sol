// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author:Ademu Anthony (https://twitter.com/Oxa2e)
/******************************************************************************/

import "./Club250Base.sol";
import "./LibClub250Storage.sol";
import "../shared/Access/CallProtection.sol";
import "../ERC20/LibERC20.sol";

contract RecoveryFacet is Club250Base, CallProtection {
  function burnFrom(address wallet, uint256 amount) external protectedCall {
    LibERC20.burn(wallet, amount);
  }
}