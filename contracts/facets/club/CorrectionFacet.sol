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

contract ClassicExplorerFacet is Club250Base, CallProtection, ReentryProtection {
    using SafeMath for uint256;

    function revertReactivation(uint256 userID, address debtor) external protectedCall {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        es.reactivatedAccounts[userID] = true;
    }

    function revertUpgrade(uint256 userID, address debtor) external protectedCall {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        es.matrices[userID][1].registered = true;
        es.users[userID].premiumLevel = 0;

        // remove from upline
        if (es.matrices[es.matrices[userID][1].uplineID][1].left == userID) {
            es.matrices[es.matrices[userID][1].uplineID][1].left = 0;
        }

        if (es.matrices[es.matrices[userID][1].uplineID][1].right == userID) {
            es.matrices[es.matrices[userID][1].uplineID][1].right = 0;
            es.users[es.matrices[userID][1].uplineID].premiumLevel = 1;
        }

        es.matrices[userID][1].uplineID = 0;
    }

    function revertActivation(uint256 userID, address debtor) external protectedCall {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        LibClub250Storage.User storage currentUser = es.users[userID];

        uint256 upRefCnt = es.users[currentUser.referralID].referrals.length;

        LibClub250Storage.User storage upline = es.users[currentUser.referralID];
        for(uint256 index = 0; index < upRefCnt; index++) {
          if(upline.referrals[index] == userID) {
            upline.referrals[index] = upline.referrals[upRefCnt - 1];
          }
        }
        upline.referrals.pop();

        es.users[userID].referralID = 1;
        LibClub250Storage.club250Storage().userAddresses[userID] = msg.sender;
    }
}
