// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PremiumBase.sol";
import "./LibClub250Storage.sol";
import { LibDiamond } from "../../libraries/LibDiamond.sol";
import "../shared/Access/CallProtection.sol";
import "../ERC20/LibERC20.sol";
import "hardhat/console.sol";

contract PremiumExtensionFacet is PremiumBase {
    using SafeMath for uint256;

    function upgradeReplacementAccount(
        uint256 userID,
        uint256 position,
        uint256 random
    ) external {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();

        require(es.live, "NA");
        require(es.users[userID].registered, "INVALID_USER_ID");
        uint256 sponsorID = es.users[userID].referralID;
        require(accountIsInPremium(sponsorID), "SPONSOR_NOT_PREMIUM");
        require(es.userAddresses[sponsorID] == msg.sender || msg.sender == LibDiamond.contractOwner(), "ACCESS_DENIED");
        require(es.users[userID].uplineID == 0 || es.users[userID].uplineID == es.users[userID].referralID, "REQUIRE_DEIFFERENT_SPONSOR");

        LibClub250Storage.User storage user = es.users[userID];

        LibERC20.burn(msg.sender, amountFromDollar(es.upgradeFee));

        uint256 today = getTheDayBefore(es.timeProvider.currentTime());
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

        emit PremiumReferralPayout(sponsorID, userID, amountFromDollar(es.upgradeFee.div(2)));

        uint256 matrixUpline = sponsorID;
        es.matrices[userID][1].registered = true;
        es.matrices[userID][1].uplineID = matrixUpline;
        es.users[userID].premiumLevel = 1;

        sendMatrixPayout(userID, 1);

        uint256 removedUserID;
        if (position == 0) {
            removedUserID = es.matrices[matrixUpline][1].left;
            es.matrices[matrixUpline][1].left = userID;
        } else {
            removedUserID = es.matrices[matrixUpline][1].left;
            es.matrices[matrixUpline][1].right = userID;
            moveToNextLevel(matrixUpline, random);
        }
        uint256 newMatrixUpline = getAvailableUplineInMatrix(removedUserID, 1, true, random);
        es.matrices[removedUserID][1].uplineID = newMatrixUpline;

        sendMatrixPayout(removedUserID, 1);

        if (es.matrices[newMatrixUpline][1].left == 0) {
            es.matrices[newMatrixUpline][1].left = userID;
        } else {
            es.matrices[newMatrixUpline][1].right = userID;
            moveToNextLevel(newMatrixUpline, random);
        }

        es.premiumCounter = es.premiumCounter.add(1);

        emit NewUpgrade(msg.sender, userID);
    }

}
