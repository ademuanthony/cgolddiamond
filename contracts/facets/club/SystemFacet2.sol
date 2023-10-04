// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author:Ademu Anthony (https://twitter.com/Oxa2e)
/******************************************************************************/

import "./Club250Base.sol";
import "./LibClub250.sol";
import "./LibClub250Storage.sol";
import "../shared/Access/CallProtection.sol";

contract SystemFacet2 is Club250Base, CallProtection {

    function updateClassicConfig() external protectedCall {
        LibClub250.buildClassicConfig();
    }
}
