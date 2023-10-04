// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author:Ademu Anthony (https://twitter.com/Oxa2e)
/******************************************************************************/


import "./LibClub250Storage.sol";
import "../ERC20/LibERC20.sol";
import "../../libraries/LibDiamond.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library LibClub250 {
    using SafeMath for uint256;

    function initialize(
        address _priceOracle,
        address _treasury
    ) internal {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        require(msg.sender == ds.contractOwner, "Must own the contract.");

        es.activationFee = 25 * 1e17;
        es.upgradeFee = 20 * 1e18;
        es.withdrawalFee = 100;
        if (es.classicReferralPercentages.length == 0) {
            es.classicReferralPercentages.push(100);
            es.classicReferralPercentages.push(70);
            es.classicReferralPercentages.push(50);
        }
        es.percentageDivisor = 1000;
        es.traversalDept = 10;

        es.classicActivationDays.push(getTheDayBefore(block.number));
        es.priceOracle = IC250PriceOracle(_priceOracle);
        es.treasury = _treasury;

        buildClassicConfig();
        buildPremiumConfig();

        if (!es.users[1].registered) {
            registerMain(msg.sender);
            es.classicIndex++;
            es.users[1].classicIndex = es.classicIndex;
            es.users[1].classicCheckpoint = block.timestamp;
        }
    }

    function registerMain(address addr) internal {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        es.lastID++;
        es.userAddresses[es.lastID] = addr;
        es.users[es.lastID].registered = true;
        es.userAccounts[addr].push(es.lastID);
    }

    function initialized() internal view returns (bool) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        return es.activationFee > 0;
    }

    function buildClassicConfig() public {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        es.classicConfigurations[1] = LibClub250Storage.ClassicConfig(1, 0, 50, 25 * 1e16, 20, 1, 0, 50);
        es.classicConfigurations[2] = LibClub250Storage.ClassicConfig(3, 2, 4000, 25 * 1e16, 40, 2, 0, 4000);
        es.classicConfigurations[3] = LibClub250Storage.ClassicConfig(6, 5, 9500, 28 * 1e16, 60, 3, 0, 9500);
        es.classicConfigurations[4] = LibClub250Storage.ClassicConfig(10, 9, 20000, 44 * 1e16, 80, 4, 0, 20000);
        es.classicConfigurations[5] = LibClub250Storage.ClassicConfig(15, 14, 45500, 66 * 1e16, 100, 5, 0, 45500);
        es.classicConfigurations[6] = LibClub250Storage.ClassicConfig(21, 20, 96000, 88 * 1e16, 120, 6, 0, 96000);
        es.classicConfigurations[7] = LibClub250Storage.ClassicConfig(28, 27, 196500, 10 * 1e17, 140, 7, 0, 196500);
        es.classicConfigurations[8] = LibClub250Storage.ClassicConfig(36, 35, 447000, 15 * 1e17, 160, 8, 0, 447000);
        es.classicConfigurations[9] = LibClub250Storage.ClassicConfig(45, 44, 947500, 20 * 1e17, 190, 9, 0, 947500);
        es.classicConfigurations[10] = LibClub250Storage.ClassicConfig(55, 54, 1948000, 30 * 1e17, 220, 10, 0, 1948000);
        es.classicConfigurations[11] = LibClub250Storage.ClassicConfig(66, 65, 3948500, 40 * 1e17, 250, 11, 0, 3948500);
        es.classicConfigurations[12] = LibClub250Storage.ClassicConfig(78, 77, 6949000, 50 * 1e17, 280, 12, 0, 6949000);
        es.classicConfigurations[13] = LibClub250Storage.ClassicConfig(91, 90, 10949500, 60 * 1e17, 330, 13, 0, 10949500);
        es.classicConfigurations[14] = LibClub250Storage.ClassicConfig(105, 104, 15950000, 70 * 1e17, 350, 14, 0, 15950000);
        es.classicConfigurations[15] = LibClub250Storage.ClassicConfig(120, 119, 21950500, 80 * 1e17, 370, 15, 0, 21950500);
        es.classicConfigurations[16] = LibClub250Storage.ClassicConfig(136, 135, 29451000, 90 * 1e17, 500, 16, 0, 29451000);
        es.classicConfigurations[17] = LibClub250Storage.ClassicConfig(153, 152, 39451500, 11 * 1e17, 1400, 17, 0, 39451500);
        es.classicConfigurations[18] = LibClub250Storage.ClassicConfig(171, 170, 64450000, 13 * 1e17, 2000, 18, 0, 64450000);
        es.classicConfigurations[19] = LibClub250Storage.ClassicConfig(190, 189, 114452500, 16 * 1e17, 2000, 19, 0, 114452500);
        es.classicConfigurations[20] = LibClub250Storage.ClassicConfig(210, 209, 214453000, 15 * 1e17, 2000, 20, 0, 214453000);
    }

    function buildPremiumConfig() private {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        es.levelConfigurations[1] = LibClub250Storage.LevelConfig(25 * 1e17, 1, 2);
        es.levelConfigurations[2] = LibClub250Storage.LevelConfig(5 * 1e18, 2, 4);

        es.levelConfigurations[3] = LibClub250Storage.LevelConfig(10 * 1e18, 1, 2);
        es.levelConfigurations[4] = LibClub250Storage.LevelConfig(10 * 1e18, 2, 4);
        es.levelConfigurations[5] = LibClub250Storage.LevelConfig(75 * 1e18, 3, 8);

        es.levelConfigurations[6] = LibClub250Storage.LevelConfig(300 * 1e18, 1, 2);
        es.levelConfigurations[7] = LibClub250Storage.LevelConfig(400 * 1e18, 2, 4);
        es.levelConfigurations[8] = LibClub250Storage.LevelConfig(875 * 1e18, 3, 8);

        es.levelConfigurations[9] = LibClub250Storage.LevelConfig(7500 * 1e18, 1, 2);
        es.levelConfigurations[10] = LibClub250Storage.LevelConfig(10000 * 1e18, 2, 4);
        es.levelConfigurations[11] = LibClub250Storage.LevelConfig(37500 * 1e18, 3, 8);

        es.levelConfigurations[12] = LibClub250Storage.LevelConfig(200000 * 1e18, 1, 2);
        es.levelConfigurations[13] = LibClub250Storage.LevelConfig(350000 * 1e18, 2, 4);
        es.levelConfigurations[14] = LibClub250Storage.LevelConfig(562500 * 1e18, 3, 8);

        es.levelConfigurations[15] = LibClub250Storage.LevelConfig(1500000 * 1e18, 1, 2);
        es.levelConfigurations[16] = LibClub250Storage.LevelConfig(2500000 * 1e18, 2, 4);
        es.levelConfigurations[17] = LibClub250Storage.LevelConfig(37500000 * 1e18, 3, 8);
        es.levelConfigurations[18] = LibClub250Storage.LevelConfig(18000000 * 1e18, 4, 16);

        // add base account to all matrix
        es.matrices[1][1].registered = true;
        es.matrices[1][2].registered = true;
        es.matrices[1][3].registered = true;
        es.matrices[1][4].registered = true;
        es.matrices[1][5].registered = true;
        es.matrices[1][6].registered = true;

        es.users[1].premiumLevel = 18;
    }

    function getTheDayBefore(uint256 timestamp) internal pure returns (uint256) {
        return timestamp.sub(timestamp % (1 days));
    }
}
