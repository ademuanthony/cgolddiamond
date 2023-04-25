// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author:Ademu Anthony (https://twitter.com/Oxa2e)
/******************************************************************************/

import "./PremiumBase.sol";
import "./LibClub250Storage.sol";
import "../shared/Access/CallProtection.sol";
import "../ERC20/LibERC20.sol";
import "hardhat/console.sol";

contract PremiumPlanFacet is PremiumBase {
    using SafeMath for uint256;

    function getUpgradeFeeInToken() external view returns (uint256) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();

        return amountFromDollar(es.upgradeFee);
    }

    function getMatrixUpline(uint256 userID, uint256 part) external view returns (uint256) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        return es.matrices[userID][part].uplineID;
    }

    function upgradeToPremium(uint256 userID, uint256 random) external noReentry {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        require(es.live, "NA");
        require(es.users[userID].registered, "INVALID_USER_ID");
        require(LibERC20.balanceOf(msg.sender) >= amountFromDollar(es.upgradeFee), "INS_BAL");
        require(es.users[userID].classicIndex > 0, "CLNA");
        require(!accountIsInPremium(userID), "DUP");

        LibClub250Storage.User storage user = es.users[userID];
        LibClub250Storage.User storage upline = es.users[user.referralID];

        LibERC20.burn(msg.sender, amountFromDollar(es.upgradeFee));

        uint256 today = getTheDayBefore(block.timestamp);
        uint256 lastPremiumDay;
        uint256 lastPremiumCount;

        if (upline.premiumActivationDays.length > 0) {
            lastPremiumDay = upline.premiumActivationDays[upline.premiumActivationDays.length - 1];

            lastPremiumCount = upline.directPremiumDownlines[lastPremiumDay];
        }
        if (lastPremiumDay < today) {
            upline.premiumActivationDays.push(today);
        }

        upline.directPremiumDownlines[today] = lastPremiumCount.add(1);

        if (accountIsInPremium(user.referralID)) {
            // upline.availableBalance += es.upgradeFee.div(2);
            sendPayout(es.userAddresses[user.referralID], es.upgradeFee.div(2), false);
            emit PremiumReferralPayout(userID, user.referralID, es.upgradeFee.div(2));
        }

        uint256 uplineID = user.uplineID > 0 ? user.uplineID : getPremiumSponsor(userID, 0);

        uint256 matrixUpline = getAvailableUplineInMatrix(uplineID, 1, true, random);
        es.matrices[userID][1].registered = true;
        es.matrices[userID][1].uplineID = matrixUpline;
        es.users[userID].premiumLevel = 1;

        sendMatrixPayout(userID, 1);

        if (es.matrices[matrixUpline][1].left == 0) {
            es.matrices[matrixUpline][1].left = userID;
        } else {
            es.matrices[matrixUpline][1].right = userID;
            moveToNextLevel(matrixUpline, random);
        }
        es.premiumCounter = es.premiumCounter.add(1);

        emit NewUpgrade(msg.sender, userID);
    }

    function setMaxtraversalDept(uint256 dept) external protectedCall {
        LibClub250Storage.club250Storage().traversalDept = dept;
    }

    function getPremiumSponsor(uint256 userID, uint256 callCount) public view returns (uint256) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        if (callCount >= 10) {
            return 1;
        }
        if (accountIsInPremium(es.users[userID].referralID)) {
            return es.users[userID].referralID;
        }

        return getPremiumSponsor(es.users[userID].referralID, callCount + 1);
    }

    function getMatrixPayoutCount(uint256 userID, uint256 level) public view returns (uint256) {
        return _getMatrixPayoutCount(userID, level);
    }

    function getDirectPremiumDownlineCount(uint256 userID) external view returns (uint256) {
        return getDirectPremiumDownlineCount(userID, block.timestamp);
    }

    function isAccountIInPremium(uint256 userID) external view returns (bool) {
        return userID == 1 || LibClub250Storage.club250Storage().users[userID].premiumLevel > 0;
    }

    function getDirectLegs(uint256 userID, uint256 level) external view returns (uint256 left, uint256 leftLevel, uint256 right, uint256 rightLevel) {
        return _getDirectLegs(userID, level);
    }

    function premiumCounter() external view returns (uint256) {
        return LibClub250Storage.club250Storage().premiumCounter;
    }
}
