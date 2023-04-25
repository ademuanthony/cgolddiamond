// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author:Ademu Anthony (https://twitter.com/Oxa2e)
/******************************************************************************/

import "./Club250Base.sol";
import "./LibClub250Storage.sol";
import "../shared/Access/CallProtection.sol";

contract SystemFacet is Club250Base, CallProtection {

    event ChangeWalletRequestCreated(uint256 indexed userID, address newWallet);

    event ChangeWalletRequestDeleted(uint256 indexed userID);

    event ChangeWalletRequestApproved(uint256 indexed userID, uint256 indexed approvingUserID);

    event WalletChanged(uint256 userID, address newWallet);

    function activationFee() external view returns(uint256) {
        return LibClub250Storage.club250Storage().activationFee;
    }
    function upgradeFee() external view returns(uint256) {
        return LibClub250Storage.club250Storage().upgradeFee;
    }
    function totalPayout() external view returns(uint256) {
        return LibClub250Storage.club250Storage().totalPayout;
    }

    function priceOracle() external view returns(address) {
        return address(LibClub250Storage.club250Storage().priceOracle);
    }

    function live() external view returns(bool) {
        return LibClub250Storage.club250Storage().live;
    }

    function classicIndex() external view returns(uint256) {
        return LibClub250Storage.club250Storage().classicIndex;
    }
    
    function getClassicConfig(uint256 level)
        external
        view
        returns (
            uint256 directReferral,
            uint256 directPremium,
            uint256 globalRequirement,
            uint256 dailyEarning,
            uint256 earningDays
        )
    {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();

        directReferral = es.classicConfigurations[level].directReferral;
        directPremium = es.classicConfigurations[level].directPremium;
        globalRequirement = es.classicConfigurations[level].globalRequirement;
        dailyEarning = es.classicConfigurations[level].dailyEarning;
        earningDays = es.classicConfigurations[level].earningDays;
    }

    function setPriceOracle(address oracle) external protectedCall {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        es.priceOracle = IC250PriceOracle(oracle);
    }

    function setTreasuryWallet(address addr) external protectedCall {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        es.treasury = addr;
    }

    function launch() external protectedCall {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        es.live = true;
    }

    function changeWallet(uint256 userID, address newWallet) public {
        require(LibClub250Storage.club250Storage().userAddresses[userID] == msg.sender, "NA");
        LibClub250Storage.club250Storage().userAddresses[userID] = newWallet;

        emit WalletChanged(userID, newWallet);
    }
    
    // @dev if a user is unable to access his wallet, his upline can make a change request
    // which must be approvef by 10 uplines before the admin can process it
    function creatChangeWalletRequest(uint256 userID, address newWallet) external {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        require(es.userAddresses[es.users[userID].referralID] == msg.sender, "NA");
        require(es.changeWalletRequests[userID].newWallet == address(0), "RE");
        es.changeWalletRequests[userID].newWallet = newWallet;
        es.changeWalletRequests[userID].approvals.push(es.users[userID].referralID);

        emit ChangeWalletRequestCreated(userID, newWallet);
        emit ChangeWalletRequestApproved(userID, es.users[userID].referralID);
    }

    function deleteChangeWalletRequest(uint256 userID) external {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        require(es.userAddresses[es.users[userID].referralID] == msg.sender || es.userAddresses[userID] == msg.sender, "NA");
        require(es.changeWalletRequests[userID].newWallet != address(0), "RNF");

        delete es.changeWalletRequests[userID];
        emit ChangeWalletRequestDeleted(userID);
    }

    function approveChangeWalletRequest(uint256 userID) external {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        uint256 lastApprovingUserID = es.changeWalletRequests[userID].approvals[es.changeWalletRequests[userID].approvals.length - 1];
        uint256 currentApprovingUserID = es.users[lastApprovingUserID].referralID;
        require(es.userAddresses[currentApprovingUserID] == msg.sender, "Not allowed");

        es.changeWalletRequests[userID].approvals.push(currentApprovingUserID);

        emit ChangeWalletRequestApproved(userID, currentApprovingUserID);
    }

    function processChangeWalletRequest(uint256 userID) external protectedCall {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();

        if (es.userAddresses[userID] == address(0)) {
            require(es.changeWalletRequests[userID].approvals.length >= 3, "Not allowed");
        } else {
            require(es.changeWalletRequests[userID].approvals.length >= 5, "Not allowed");
        }

        es.userAddresses[userID] = es.changeWalletRequests[userID].newWallet;

        emit WalletChanged(userID, es.changeWalletRequests[userID].newWallet);
    }

    function getAmountFromDollar(uint256 _dollarAmount) external view returns(uint256) {
        return amountFromDollar(_dollarAmount);
    }

    function addGlobalIndex(uint256 value) external protectedCall {
        LibClub250Storage.club250Storage().classicIndex = LibClub250Storage.club250Storage().classicIndex + value;
    }
}
