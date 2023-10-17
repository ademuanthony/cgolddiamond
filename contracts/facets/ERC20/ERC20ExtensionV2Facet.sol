// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../libraries/LibDiamond.sol";
import "../../interfaces/IERC20Facet.sol";
import "./LibERC20Storage.sol";
import "./LibERC20.sol";
import "../shared/Access/CallProtection.sol";

contract ERC20ExtensionV2Facet is CallProtection {
    using SafeMath for uint256;

    function blacklist(address acc, bool val) external protectedCall {
        LibERC20Storage.erc20Storage().blacklisted[acc] = val;
    }

    function setExchangeAddress(address exchange, bool isExchanage) external protectedCall {
        LibERC20Storage.erc20Storage().exchange[exchange] = isExchanage;
    }
}
