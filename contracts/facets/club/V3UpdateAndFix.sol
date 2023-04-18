// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Club250Base.sol";
import "./LibClub250Storage.sol";
import "../shared/Access/CallProtection.sol";
import "../ERC20/LibERC20.sol";

contract V3UpdateAndFix is Club250Base, CallProtection {
    function setClassicReferral() external protectedCall {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        es.classicReferralPercentages[0] = 100;
        es.classicReferralPercentages[1] = 70;
        es.classicReferralPercentages[2] = 50;
    }
}
