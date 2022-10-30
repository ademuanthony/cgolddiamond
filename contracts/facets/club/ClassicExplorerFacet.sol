// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Club250Base.sol";
import "./LibClub250Storage.sol";
import "../shared/Access/CallProtection.sol";
import "../shared/Reentry/ReentryProtection.sol";
import "../ERC20/LibERC20.sol";
import "hardhat/console.sol";

contract ClassicExplorerFacet is Club250Base, CallProtection, ReentryProtection {
    using SafeMath for uint256;

    // @dev returns the current unpaid earnings of the user
    function withdrawableAlt(uint256 userID) external view returns (uint256, uint256) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        LibClub250Storage.User storage user = es.users[userID];
        uint256 amount;

        uint256 earningCounter;
        uint256 lastLevel;

        uint256 today = getTheDayBefore(block.timestamp);

        for (uint256 day = getTheDayBefore(user.classicCheckpoint); day < today; day += (1 days)) {
            if (getWeekday(day) == 0) {
                continue;
            }
            uint256 level = publicGClassicLevelAt(userID, day);
            if (level == 0 && lastLevel == 0) continue;
            if (level != lastLevel) {
                lastLevel = level;
                earningCounter = 0;
            }

            if (user.classicEarningCount[lastLevel].add(earningCounter) < es.classicConfigurations[lastLevel].earningDays) {
                amount = amount.add(es.classicConfigurations[lastLevel].dailyEarning);
                earningCounter = earningCounter.add(1);
            }
        }

        return (amount, user.classicEarningCount[lastLevel].add(earningCounter));
    }

    function publicGetDirectPremiumDownlineCount(uint256 userID, uint256 timestamp) public view returns (uint256) {
        return getDirectPremiumDownlineCount(userID, timestamp);
    }

    function getWeekday(uint256 timestamp) private pure returns (uint8) {
        return uint8((timestamp / (1 days) + 4) % 7);
    }

    // @dev returns the classic level in which the user is qaulified to earn at the given timestamp
    function publicGClassicLevelAt(uint256 userID, uint256 timestamp) public view returns (uint256) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        LibClub250Storage.User storage user = es.users[userID];
        uint256 directDownlineCount = user.referrals.length;
        if (directDownlineCount == 0 || user.activationDays.length == 0) {
            return (0);
        }

        timestamp = getTheDayBefore(timestamp.add(1 days));
        if (timestamp < user.activationDays[0]) {
            return 0;
        }

        uint256 globalIndex = es.classicIndex;

        uint256 directPremiumCount = getDirectPremiumDownlineCount(userID, timestamp);
        // if the day is < his first activation date, 0

        for (uint256 i = user.activationDays.length - 1; i >= 0; i--) {
            if (user.activationDays[i] <= timestamp) {
                directDownlineCount = user.activeDownlines[user.activationDays[i]];
                globalIndex = es.activeGlobalDownlines[user.activationDays[i]];
                break;
            }
        }

        (, uint256 globalDownlines) = globalIndex.trySub(user.classicIndex);

        for (uint256 i = 20; i > 0; i--) {
            if (
                es.classicConfigurations[i].directPremium <= directPremiumCount &&
                es.classicConfigurations[i].directReferral <= directDownlineCount &&
                es.classicConfigurations[i].globalRequirement <= globalDownlines
            ) {
                if (!accountIsInPremium(userID)) {
                    return (1);
                }
                return (i);
            }
        }
        return (0);
    }

    function classicLevelStandAt(uint256 userID, uint256 timestamp) public view returns (uint256) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        LibClub250Storage.User storage user = es.users[userID];
        uint256 directDownlineCount = user.referrals.length;
        if (directDownlineCount == 0 || user.activationDays.length == 0) {
            return (0);
        }

        if (timestamp < user.activationDays[0]) {
            return (0);
        }

        uint256 globalIndex = es.classicIndex;

        uint256 directPremiumCount = getDirectPremiumDownlineCount(userID, timestamp);

        if (getTheDayBefore(timestamp) != getTheDayBefore(block.timestamp)) {
            for (uint256 i = user.activationDays.length - 1; i >= 0; i--) {
                if (user.activationDays[i] <= timestamp) {
                    directDownlineCount = user.activeDownlines[user.activationDays[i]];
                    globalIndex = es.activeGlobalDownlines[user.activationDays[i]];
                    break;
                }
            }
        }

        (, uint256 globalDownlines) = globalIndex.trySub(user.classicIndex);

        for (uint256 i = 20; i > 0; i--) {
            if (
                es.classicConfigurations[i].directPremium <= directPremiumCount &&
                es.classicConfigurations[i].directReferral <= directDownlineCount &&
                es.classicConfigurations[i].globalRequirement <= globalDownlines
            ) {
                if (!accountIsInPremium(userID)) {
                    return (0);
                }
                return (i);
            }
        }
        return (0);
    }

    function getDirectPremiumDownlineCountExt(uint256 userID, uint256 timestamp) external view returns (uint256) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        LibClub250Storage.User storage user = es.users[userID];
        uint256 premiumActivationDaysCount = user.premiumActivationDays.length;
        if (premiumActivationDaysCount == 0) {
            return 0;
        }

        if (premiumActivationDaysCount == 1) {
            if (user.premiumActivationDays[0] > timestamp) {
                return 0;
            }
            return user.directPremiumDownlines[user.premiumActivationDays[0]];
        }

        for (int256 i = int256(premiumActivationDaysCount - 1); i >= 0; i--) {
            if (i < 0) break;
            if (user.premiumActivationDays[uint256(i)] <= timestamp) {
                return user.directPremiumDownlines[user.premiumActivationDays[uint256(i)]];
            }
        }

        return 0;
    }

    function setClassicPayoutState(uint256 _payin, uint256 _payout) external protectedCall {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        es.classicDeposit = _payin;
        es.classicWithdrawal = _payout;
    }

    function classicPaymentState(uint256 _day) external view returns (uint256 payin, uint256 payout) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        if(es.runningWithdrawalCloseTime <= block.timestamp) {
            payin = 100;
            payout = 100;
        }
        payin = es.classicDeposit;
        payout = es.classicWithdrawal;
    }
}
