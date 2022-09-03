/**
 *SPDX-License-Identifier: UNLICENSED
 */
pragma solidity ^0.8.0;

contract MockC250PriceOracle {

    function getQuote(
        address tokenOut,
        uint128 amountIn,
        uint32 secondsAgo
    ) external pure returns (uint256 amountOut) {
        amountOut = amountIn;
    }
}
