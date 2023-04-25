// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author:Ademu Anthony (https://twitter.com/Oxa2e)
/******************************************************************************/


library LibERC1115Storage {
    bytes32 constant ERC_1115_STORAGE_POSITION = keccak256("C250Gold.storage.location.erc1115");

    struct ERC1115Storage {
        // Mapping from token ID to account balances
        mapping(uint256 => mapping(address => uint256)) balances;
        // Mapping from account to operator approvals
        mapping(address => mapping(address => bool)) operatorApprovals;
        // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
        mapping(uint256 => string) categoryUri;
        // Mapping from token ID to category index
        mapping(uint256 => uint256) tokenCategory;
        // Number of tokens in each category
        Category[] categories;
        // Mapping of address to all here held token ID
        mapping(address => uint256[]) holdings;
        // Mapping of tokens that the user've locked to the date, for a higher earnigs in classic
        mapping(uint256 => uint256) lockInDates;
        // Mapping of token categories that can be linked
        mapping(uint256 => LinkConfig) linkConfigs;
    }

    struct Category {
      string uri;
      uint256 totalSupply;
      uint256 maxSupply;
      string name;
      string symbol;
      uint256 mintingPrice;
    }

    struct LinkConfig {
        uint256 coolDownPeriod;
        uint256 power;
        uint256 powerDenominator;
    }

    function erc1115Storage() internal pure returns (ERC1115Storage storage es) {
        bytes32 position = ERC_1115_STORAGE_POSITION;
        assembly {
            es.slot := position
        }
    }
}
