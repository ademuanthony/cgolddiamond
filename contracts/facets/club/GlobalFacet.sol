// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Club250Base.sol";
import "./LibClub250Storage.sol";
import "../shared/Access/CallProtection.sol";

contract GlobalFacet is Club250Base, CallProtection {
    function addGlobalIndex(uint256 value) external protectedCall {
        LibClub250Storage.club250Storage().classicIndex = LibClub250Storage.club250Storage().classicIndex + value;
    }
}
