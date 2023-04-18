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

    function reactivate(uint256 userID) external {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        require(!es.reactivatedAccounts[userID], "already done");

        uint256 feeAmount = amountFromDollar(es.activationFee);
        require(LibERC20.balanceOf(msg.sender) >= feeAmount, "INS_BAL");
        LibERC20.burn(msg.sender, feeAmount);

        es.reactivatedAccounts[userID] = true;
        es.users[userID].availableBalance = 0;
        es.users[userID].classicCheckpoint = block.timestamp;
    }
}
