// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author:Ademu Anthony (https://twitter.com/Oxa2e)
/******************************************************************************/

library LibClub250Storage {
    bytes32 constant CLUB250_STORAGE_POSITION = keccak256("CLUB250.storage.location");

    struct CLUB250Storage {
        bool live;
        uint256 activationFee;
        uint256 upgradeFee;
        uint256 withdrawalFee;
        uint256[] classicReferralPercentages;
        uint256 percentageDivisor;
        IC250PriceOracle priceOracle;
        address treasury;
        mapping(uint256 => ClassicConfig) classicConfigurations;
        uint256 totalPayout;
        uint256 lastID;
        uint256 classicIndex;
        uint256[] classicActivationDays;
        // @dev holds the total number of global downlines on each day
        mapping(uint256 => uint256) activeGlobalDownlines;
        // @dev mapping of id to address
        mapping(uint256 => address) userAddresses;
        // @dev mapping of id to user
        mapping(uint256 => User) users;
        // @dev list of accounts associated with an address
        mapping(address => uint256[]) userAccounts;
        mapping(uint256 => ChangeWalletRequest) changeWalletRequests;
        uint256 premiumCounter;
        uint256[] premiumAccounts;
        uint256 traversalDept;
        // @dev user's matric for each part
        mapping(uint256 => mapping(uint256 => Matrix)) matrices;
        mapping(uint256 => LevelConfig) levelConfigurations;

        mapping(uint256 => uint256) classicPayout;
        mapping(uint256 => uint256) classicPayin;

        uint256 classicWithdrawal;
        uint256 runningWithdrawalCloseTime;
        uint256 classicDeposit;
        uint256 lastClassicWithdrawal;
        uint256 controlStartdate;

        address lagacyVersion;
        address claimSender;

        mapping(uint256 => bool) v1ClaimedIds;

        mapping(uint256 => bool) reactivatedAccounts;
    }

    struct ClassicConfig {
        uint256 directReferral;
        uint256 directPremium;
        uint256 globalRequirement;

        uint256 dailyEarning;
        uint256 earningDays;
        
        uint256 directReferralRe;
        uint256 directPremiumRe;
        uint256 globalRequirementRe;
    }

    struct User {
        bool registered;
        uint256 classicIndex;
        uint256 classicCheckpoint;
        uint256 referralID;
        uint256 uplineID;
        uint256 premiumLevel;
        uint256[] referrals;
        uint256[] activationDays;
        mapping(uint256 => uint256) activeDownlines;
        uint256[] premiumActivationDays;
        mapping(uint256 => uint256) directPremiumDownlines;
        mapping(uint256 => uint256) classicEarningCount;
        mapping(uint256 => CircleCheckpoint[]) classicCircles;
        mapping(uint256 => uint256) classicCircleCount;

        uint256 availableBalance;
        uint256 classicBalance;
    }

    struct CircleCheckpoint {
        uint256 directReferrals;
        uint256 directPremium;
        uint256 globalDownlines;
    }

    struct ChangeWalletRequest {
        address newWallet;
        uint256[] approvals;
    }

    struct Matrix {
        bool registered;
        uint256 uplineID;
        uint256 left;
        uint256 right;
    }

    struct LevelConfig {
        uint256 perDropEarning;
        uint256 paymentGeneration;
        uint256 numberOfPayments;
    }

    function club250Storage() internal pure returns (CLUB250Storage storage es) {
        bytes32 position = CLUB250_STORAGE_POSITION;
        assembly {
            es.slot := position
        }
    }
}

interface IC250PriceOracle {
    function getQuote(
        address tokenOut,
        uint128 amountIn,
        uint32 secondsAgo
    ) external view returns (uint256 amountOut);
}

interface ITimeProvider {
    function currentTime() external view returns (uint256 amountOut);
}
