// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Club250Base.sol";
import "./LibClub250Storage.sol";
import "../shared/Access/CallProtection.sol";
import "../ERC20/LibERC20.sol";

/******************************************************************************\
* Author:Ademu Anthony (https://twitter.com/Oxa2e)
/******************************************************************************/

contract V3UpdateAndFix is Club250Base, CallProtection {
    function setClassicReferral() external protectedCall {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        es.classicReferralPercentages[0] = 100;
        es.classicReferralPercentages[1] = 70;
        es.classicReferralPercentages[2] = 50;
    }

    function reactivate(uint256 userID) external {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        require(!userCanEarn(userID), "already done");

        uint256 feeAmount = amountFromDollar(es.activationFee);
        require(LibERC20.balanceOf(msg.sender) >= feeAmount, "INS_BAL");
        LibERC20.burn(msg.sender, feeAmount);

        es.reactivatedAccounts[userID] = true;
        es.users[userID].availableBalance = 0;
        es.users[userID].classicCheckpoint = block.timestamp;
    }

    function isAccountActive(uint256 userID) external view returns(bool) {
        return userCanEarn(userID);
    }

    function updateClassicRequirement() external protectedCall {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        es.classicConfigurations[1] = LibClub250Storage.ClassicConfig(1, 0, 50, 25 * 1e16, 20, 1, 0, 50);
    }
}
