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
        if (user.premiumActivationDays.length == 0) {
            return 0;
        }

        if(user.premiumActivationDays.length == 1 && user.premiumActivationDays[user.premiumActivationDays.length-1] > timestamp) {
            return 0;
        }

        for (uint256 i = user.premiumActivationDays.length - 1; i >= 0; i--) {
            if (user.premiumActivationDays[i] <= timestamp) {
                return user.directPremiumDownlines[user.premiumActivationDays[i]];
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

    function sendPayout(address account, uint256 dollarAmount) internal {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        uint256 tokenAmount = amountFromDollar(dollarAmount);
        uint256 fee = tokenAmount.mul(es.withdrawalFee).div(es.percentageDivisor);

        LibERC20.mint(es.treasury, fee);
        if (account == address(0)) {
            account = es.treasury;
        }
        LibERC20.mint(account, tokenAmount.sub(fee));
        emit Withdrawal(msg.sender, dollarAmount);
    }
}
