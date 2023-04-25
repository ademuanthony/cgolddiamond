// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author:Ademu Anthony (https://twitter.com/Oxa2e)
/******************************************************************************/

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./Club250Base.sol";
import "./LibClub250Storage.sol";
import "../shared/Access/CallProtection.sol";
import "../shared/Reentry/ReentryProtection.sol";
import "../ERC20/LibERC20.sol";
import "hardhat/console.sol";

interface CgoldLagacy {
    function users(uint256 _id)
        external
        returns (
            bool registered,
            uint256 classicIndex,
            uint256 classicCheckpoint,
            uint256 referralID,
            uint256 uplineID,
            uint256 premiumLevel,
            bool imported,
            uint256 importedReferralCount,
            uint256 importClassicLevel,
            uint256 outstandingBalance
        );

    function userAddresses(uint256 _id) external returns (address);

    function userAccounts(address _addr, uint256 _index) external returns (uint256);
}

contract MigrationFacet is Club250Base, CallProtection, ReentryProtection {
    using SafeMath for uint256;

    function setLagacyVersion(address token, address claimSender) external protectedCall {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        es.lagacyVersion = token;
        es.claimSender = claimSender;
    }

    function claimV2Token(address _address) external {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        IERC20 v1Contract = IERC20(es.lagacyVersion);

        uint256 balance = v1Contract.balanceOf(_address);
        require(balance > 0, "MigrationFacet: Nothing to claim");

        v1Contract.transferFrom(_address, address(this), balance);
        LibERC20.mint(_address, balance, false);
    }

    function sendClaim(address _to, uint256 _amount) internal {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        LibERC20.mint(_to, _amount, false);
        LibERC20.burn(es.claimSender, _amount);
    }
}

contract Migration2Facet is Club250Base {
    using SafeMath for uint256;

    function claimSpentV1Tokens(address addr, uint256[] calldata indices) external {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        CgoldLagacy v1Contract = CgoldLagacy(es.lagacyVersion);
        uint256 amount;
        for (uint256 i = 0; i < indices.length; i++) {
            if(i >= indices.length) {
                break;
            }
            uint256 id = v1Contract.userAccounts(addr, indices[i]);

            if (es.v1ClaimedIds[id] == true) {
                continue;
            }
            es.v1ClaimedIds[id] = true;

            (bool registered, uint256 classicIndex, , , , uint256 premiumLevel, bool imported, , , uint256 outstandingBalance) = v1Contract.users(id);

            if (!registered || classicIndex == 0) {
                continue;
            }

            if (!imported) {
                amount = amount.add(es.activationFee);
                if (premiumLevel > 0) {
                    amount = amount.add(es.upgradeFee);
                }
            }

            amount = amount.add(outstandingBalance);
        }

        require(amount > 0, "claimSpentV1Tokens: Nothing to claim");

        sendClaim(addr, amount);
    }

    function sendClaim(address _to, uint256 _amount) internal {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        LibERC20.mint(_to, _amount, false);
        LibERC20.burn(es.claimSender, _amount);
    }
}

contract Migration3Facet is Club250Base, CallProtection, ReentryProtection {
    function setLagacyVersion(address token, address claimSender) external protectedCall {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        es.lagacyVersion = token;
        es.claimSender = claimSender;
    }

    function getLagacyVersion() external view returns (address) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        return es.lagacyVersion;
    }
}
