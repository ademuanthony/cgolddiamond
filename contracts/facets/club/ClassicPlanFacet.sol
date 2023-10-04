// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author:Ademu Anthony (https://twitter.com/Oxa2e)
/******************************************************************************/

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Club250Base.sol";
import "./LibClub250Storage.sol";
import "../shared/Access/CallProtection.sol";
import "../shared/Reentry/ReentryProtection.sol";
import "../ERC20/LibERC20.sol";
import "hardhat/console.sol";

contract ClassicPlanFacet is Club250Base, CallProtection, ReentryProtection {
    using SafeMath for uint256;

    event NewUser(address indexed user, uint256 indexed id, uint256 indexed referrer);
    event NewActivation(address indexed by, uint256 indexed id);
    event ClassicRefBonus(uint256 user, uint256 upline, uint256 generation);

    function getActivationFeeInToken() external view returns (uint256) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();

        return amountFromDollar(es.activationFee);
    }

    function referralCount(uint256 userID) external view returns (uint256) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        return es.users[userID].referrals.length;
    }

    function getReferrals(uint256 userID, uint256 startIndex) external view returns (uint256[20] memory) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        uint256[20] memory ids;
        if (es.users[userID].referrals.length > startIndex) {
            for (uint256 i = 0; i < 10; i++) {
                if (i + startIndex >= es.users[userID].referrals.length) {
                    break;
                }
                ids[i] = es.users[userID].referrals[i + startIndex];
            }
        }
        return ids;
    }

    function getLinkAccounts(uint256 userID, uint256 startIndex) external view returns (uint256[10] memory) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        uint256[10] memory ids;
        if (es.userAccounts[es.userAddresses[userID]].length > startIndex) {
            for (uint256 i = 0; i < 10; i++) {
                if (i + startIndex >= es.userAccounts[es.userAddresses[userID]].length) {
                    break;
                }
                ids[i] = es.userAccounts[es.userAddresses[userID]][i + startIndex];
            }
        }
        return ids;
    }

    function classicEarningByUser(uint256 userID, uint256 day) external view returns (uint256) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        return es.users[userID].classicEarningCount[getClassicLevelAt(userID, day)];
    }

    function getAccounts(address addr, uint256 startIndex) external view returns (uint256[20] memory) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        uint256[20] memory result;
        for (uint256 i = 0; i < 20; i++) {
            if (i + startIndex >= es.userAccounts[addr].length) {
                break;
            }
            result[i] = es.userAccounts[addr][startIndex + i];
        }
        return result;
    }

    function getAccountsCount(address addr) external view returns (uint256) {
        return LibClub250Storage.club250Storage().userAccounts[addr].length;
    }

    function _register(uint256 referralID, uint256 uplineID, address addr) internal {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        require(referralID <= es.lastID, "NF");
        es.lastID++;
        es.userAddresses[es.lastID] = addr;
        es.users[es.lastID].registered = true;
        es.users[es.lastID].referralID = referralID;
        // @dev if an upline is supplied, it must be a premium account. ID 1 is premium by default
        if (uplineID > 0) {
            require(accountIsInPremium(uplineID), "UPNIP");
            es.users[es.lastID].uplineID = uplineID;
        }
        es.userAccounts[addr].push(es.lastID);

        emit NewUser(addr, es.lastID, referralID);
    }

    function registerAndActivate(uint256 referralID, uint256 uplineID, address addr) external {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        register(referralID, uplineID, addr);
        activate(es.lastID);
    }

    function addAndActivateMultipleAccounts(uint256 referralID, uint256 uplineID, address addr, uint256 no) external {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        require(no <= 50, "TOO_MANY");
        require(LibERC20.balanceOf(msg.sender) >= amountFromDollar(es.activationFee).mul(no), "ISB");

        for (uint256 i = 0; i < no; i++) {
            _register(referralID, uplineID, addr);
            activate(es.lastID);
        }
    }

    function withdraw(uint256 userID) public noReentry {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        require(es.userAddresses[userID] == msg.sender, "ACCESS_DENIED");
        (uint256 dollarAmount, uint256 earningCounter) = withdrawable(userID);
        require(dollarAmount > 5e18, "MIN_WITHDRAWAL");

        es.users[userID].classicBalance = 0;

        // require(es.runningWithdrawalCloseTime >= block.timestamp, "NO_RUNNING_WITHDRAWAL_WINDOW");
        require(es.users[userID].premiumLevel > 0, "NOT_IN_PREMIUM");

        es.classicWithdrawal = es.classicWithdrawal.add(dollarAmount).sub(es.users[userID].availableBalance);

        es.users[userID].classicCheckpoint = block.timestamp;
        es.users[userID].classicEarningCount[getClassicLevelAt(userID, block.timestamp)] = earningCounter;

        sendPayout(msg.sender, dollarAmount, false);
    }

    function withdrawToWallet(uint256 userID) private noReentry {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        require(es.userAddresses[userID] == msg.sender, "ACCESS_DENIED");
        (uint256 dollarAmount, uint256 earningCounter) = withdrawable(userID);

        es.classicWithdrawal = es.classicWithdrawal.add(dollarAmount).sub(es.users[userID].availableBalance);

        es.users[userID].classicCheckpoint = block.timestamp;
        es.users[userID].classicEarningCount[getClassicLevelAt(userID, block.timestamp)] = earningCounter;

        es.users[userID].classicBalance = dollarAmount;
    }

    function getWeekday(uint256 timestamp) public pure returns (uint8) {
        return uint8((timestamp / (1 days) + 4) % 7);
    }

    function register(uint256 referralID, uint256 uplineID, address addr) public noReentry validReferralID(referralID) {
        require(LibClub250Storage.club250Storage().live, "NS");
        require(LibClub250Storage.club250Storage().userAccounts[addr].length == 0, "DUP");
        _register(referralID, uplineID, addr);
    }

    function activate(uint256 id) public noReentry {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        require(es.live, "NS");
        require(es.userAddresses[id] != address(0), "NF");

        LibClub250Storage.User storage currentUser = es.users[id];

        require(currentUser.classicIndex == 0, "DUP");
        uint256 feeAmount = amountFromDollar(es.activationFee);
        require(LibERC20.balanceOf(msg.sender) >= feeAmount, "INS_BAL");
        LibERC20.burn(msg.sender, feeAmount);
        currentUser.classicIndex = ++es.classicIndex;
        currentUser.classicCheckpoint = block.timestamp;
        uint256 today = getTheDayBefore(block.timestamp);

        if (currentUser.referralID != 0) {
            LibClub250Storage.User storage upline = es.users[currentUser.referralID];
            upline.referrals.push(id);
            if (upline.activationDays.length == 0 || upline.activationDays[upline.activationDays.length - 1] < today) {
                upline.activationDays.push(today);
            }
            upline.activeDownlines[today] = upline.referrals.length;

            // uint256 refTotal;
            uint256 referralID = currentUser.referralID;
            for (uint256 i = 0; i < es.classicReferralPercentages.length; i++) {
                if (referralID != 0) {
                    uint256 refAmount = es.activationFee.mul(es.classicReferralPercentages[i]).div(es.percentageDivisor);
                    es.users[referralID].availableBalance += refAmount;
                    emit ClassicRefBonus(id, referralID, i + 1);
                    referralID = es.users[referralID].referralID;
                    continue;
                }
                break;
            }
            // if (refTotal > 0) {
            //     es.totalPayout = es.totalPayout.add(refTotal);
            // }
        }

        es.classicDeposit = es.classicDeposit.add(es.activationFee);
        if (es.classicDeposit >= es.classicWithdrawal && es.runningWithdrawalCloseTime <= block.timestamp) {
            es.runningWithdrawalCloseTime = block.timestamp.add(3 days);
            es.classicDeposit = 0;
            es.classicWithdrawal = 0;
        }

        // taking the snapshot of the number of classic accounts
        es.activeGlobalDownlines[today] = es.classicIndex;
        if (today != es.classicActivationDays[es.classicActivationDays.length - 1]) {
            es.classicActivationDays.push(today);
        }

        emit NewActivation(msg.sender, id);
    }

    function earningsCount(uint256 userID) public view returns (uint256) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        uint256 level = getClassicLevelAt(userID, block.timestamp);
        return es.users[userID].classicEarningCount[level];
    }

    // @dev returns the current unpaid earnings of the user
    function withdrawable(uint256 userID) public view returns (uint256, uint256) {
        if (!userCanEarn(userID)) {
            return (0, 0);
        }

        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        LibClub250Storage.User storage user = es.users[userID];
        if (user.activationDays.length == 0) {
            return (0, 0);
        }
        uint256 amount;

        uint256 earningCounter;
        uint256 lastLevel;

        uint256 today = getTheDayBefore(block.timestamp);
        if (getTheDayBefore(user.classicCheckpoint) == today) {
            return (0, 0);
        }

        for (uint256 day = getTheDayBefore(user.classicCheckpoint + 1 days); day <= today; day += (1 days)) {
            if (getWeekday(day) == 0) {
                continue;
            }

            if (day == user.activationDays[0]) {
                continue;
            }

            uint256 level = getClassicLevelAt(userID, day);
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

        amount += user.availableBalance;
        amount += user.classicBalance;

        return (amount, user.classicEarningCount[lastLevel].add(earningCounter));
    }

    // @dev returns the classic level in which the user is qaulified to earn at the given timestamp
    function getClassicLevelAt(uint256 userID, uint256 timestamp) internal view returns (uint256) {
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

    // @dev returns the current classic level of the user
    function getClassicLevel(uint256 userID) public view returns (uint256) {
        return getClassicLevelAt(userID, block.timestamp);
    }

    function getGlobalDownlines(uint256 _userID) public view returns (uint256) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        LibClub250Storage.User storage user = es.users[_userID];
        return es.classicIndex - user.classicIndex;
    }

    function recircle(uint256 _userID) external {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        LibClub250Storage.User storage user = es.users[_userID];
        uint256 level = getClassicLevelAt(_userID, block.timestamp);
        LibClub250Storage.ClassicConfig memory config = es.classicConfigurations[level];

        (uint256 amount, ) = withdrawable(_userID);
        if (amount > 0) {
            withdrawToWallet(_userID);
        }

        uint256 globalDownlines = getGlobalDownlines(_userID);
        uint256 directReferrals = user.referrals.length;
        uint256 directPremium = getDirectPremiumDownlineCount(_userID, block.timestamp);

        (uint256 globalExcess, uint256 directReferralsExcess, uint256 directPremiumExcess) = excessQualification(_userID);
        require(
            globalExcess >= config.globalRequirementRe &&
                directReferralsExcess >= config.directReferralRe &&
                directPremiumExcess >= config.directPremiumRe,
            "NOT_QUALIFIY"
        );
        user.classicCircles[level].push(LibClub250Storage.CircleCheckpoint(globalDownlines, directReferrals, directPremium));

        user.classicCheckpoint = block.timestamp;
        user.classicEarningCount[level] = 0;
    }

    function excessQualification(
        uint256 _userID
    ) public view returns (uint256 globalExcess, uint256 directReferralsExcess, uint256 directPremiumExcess) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        LibClub250Storage.User storage user = es.users[_userID];
        uint256 level = getClassicLevelAt(_userID, block.timestamp);
        LibClub250Storage.ClassicConfig memory config = es.classicConfigurations[level];

        uint256 globalDownlines = getGlobalDownlines(_userID);
        uint256 directReferrals = user.referrals.length;
        uint256 directPremium = getDirectPremiumDownlineCount(_userID, block.timestamp);

        uint256 circleCount = user.classicCircleCount[level];

        if (circleCount > 0) {
            LibClub250Storage.CircleCheckpoint memory lastCircle = user.classicCircles[level][circleCount - 1];
            globalExcess = globalDownlines.sub(lastCircle.globalDownlines);
            directReferralsExcess = directReferrals.sub(lastCircle.directReferrals);
            directPremiumExcess = directPremium.sub(lastCircle.directPremium);
        } else {
            globalExcess = globalDownlines.sub(config.globalRequirement);
            directReferralsExcess = directReferrals.sub(config.directReferral);
            directPremiumExcess = directPremium.sub(config.directPremium);
        }
    }

    function getUser(
        uint256 userID
    )
        external
        view
        returns (
            bool registered,
            uint256 classicIndex,
            uint256 classicCheckpoint,
            uint256 referralID,
            uint256 uplineID,
            uint256 premiumLevel,
            uint256 referralsCount
        )
    {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        LibClub250Storage.User storage user = es.users[userID];

        registered = user.registered;
        classicIndex = user.classicIndex;
        classicCheckpoint = user.classicCheckpoint;
        referralID = user.referralID;
        uplineID = user.uplineID;
        premiumLevel = user.premiumLevel;
        referralsCount = user.referrals.length;
    }

    function lastID() external view returns (uint256) {
        return LibClub250Storage.club250Storage().lastID;
    }

    function userAddresses(uint256 userID) external view returns (address) {
        return LibClub250Storage.club250Storage().userAddresses[userID];
    }
}
