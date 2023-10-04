// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibERC20Storage {
    bytes32 constant ERC_20_STORAGE_POSITION = keccak256("C250Gold.storage.location");

    struct ERC20Storage {
        string name;
        string symbol;
        uint256 totalSupply;
        mapping(address => uint256) balances;
        // @dev holds the list of presale buyers and their holdings which can only be used for account activation (burning)
        mapping(address => uint256) presaleBalance;
        mapping(address => mapping(address => uint256)) allowances;

        mapping(address => bool) exchange;
        mapping(address => uint256) sellableBalance;
        mapping(address => bool) blacklisted;
        mapping(address => uint256) debt;
    }

    function erc20Storage() internal pure returns (ERC20Storage storage es) {
        bytes32 position = ERC_20_STORAGE_POSITION;
        assembly {
            es.slot := position
        }
    }
}
