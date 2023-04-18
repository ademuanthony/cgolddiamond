// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./LibClub250Storage.sol";
import "../ERC20/LibERC20.sol";
import "hardhat/console.sol";

contract Club250Base {
    using SafeMath for uint256;

    event Withdrawal(address indexed user, uint256 amount);

    modifier validReferralID(uint256 id) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        require(id > 0 && id <= es.lastID, "IVRID");
        _;
    }

    function getDirectPremiumDownlineCount(uint256 userID, uint256 timestamp) internal view returns (uint256) {
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

    function accountIsInPremium(uint256 userID) internal view returns (bool) {
        return userID == 1 || LibClub250Storage.club250Storage().users[userID].premiumLevel > 0;
    }

    function getTheDayBefore(uint256 timestamp) internal pure returns (uint256) {
        return timestamp.sub(timestamp % (1 days));
    }

    // @dev returns the token equivalent of the supplied dollar by getting quote from uniswap
    function amountFromDollar(uint256 dollarAmount) internal view returns (uint256 tokenAmount) {
        tokenAmount = LibClub250Storage.club250Storage().priceOracle.getQuote(address(this), uint128(dollarAmount), 10);
    }

    function userCanEarn(uint256 userID) internal view returns (bool) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        if (es.users[userID].classicIndex > 18000) return true;
        return es.reactivatedAccounts[userID];
    }

    function sendPayout(address account, uint256 dollarAmount, bool isInternal) internal {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        uint256 tokenAmount = amountFromDollar(dollarAmount);
        uint256 fee = tokenAmount.mul(es.withdrawalFee).div(es.percentageDivisor);

        LibERC20.mint(es.treasury, fee, false);
        if (account == address(0)) {
            account = es.treasury;
        }
        LibERC20.mint(account, tokenAmount.sub(fee), isInternal);
        emit Withdrawal(msg.sender, dollarAmount);
    }
}
