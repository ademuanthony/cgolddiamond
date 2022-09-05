// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

        LibERC20.burn(msg.sender, amountFromDollar(es.upgradeFee));

        uint256 today = getTheDayBefore(block.timestamp);
        uint256 lastPremiumDay;
        uint256 lastPremiumCount;

        if (es.users[es.users[userID].referralID].premiumActivationDays.length > 0) {
            lastPremiumDay = es.users[es.users[userID].referralID].premiumActivationDays[
                es.users[es.users[userID].referralID].premiumActivationDays.length - 1
            ];

            lastPremiumCount = es.users[es.users[userID].referralID].directPremiumDownlines[lastPremiumDay];
        }
        if (lastPremiumDay < today) {
            es.users[es.users[userID].referralID].premiumActivationDays.push(today);
        }

        es.users[es.users[userID].referralID].directPremiumDownlines[today] = lastPremiumCount.add(1);

        address referralEarner = address(0);
        if (accountIsInPremium(user.referralID)) {
            referralEarner = es.userAddresses[user.referralID];
        }
        sendPayout(referralEarner, amountFromDollar(es.upgradeFee.div(2)), true);

        uint256 sponsorID = getPremiumSponsor(userID, 0);
        emit PremiumReferralPayout(sponsorID, userID, amountFromDollar(es.upgradeFee.div(2)));

        uint256 uplineID = sponsorID;
        if (user.uplineID > 0) {
            uplineID = user.uplineID;
        }

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

    function getDirectLegs(uint256 userID, uint256 level)
        external
        view
        returns (
            uint256 left,
            uint256 leftLevel,
            uint256 right,
            uint256 rightLevel
        )
    {
        return _getDirectLegs(userID, level);
    }

    function premiumCounter() external view returns (uint256) {
        return LibClub250Storage.club250Storage().premiumCounter;
    }
}
