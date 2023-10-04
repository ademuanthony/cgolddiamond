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

contract CasinoFacet is Club250Base, CallProtection, ReentryProtection {
    using SafeMath for uint256;

    function placeBet(uint256 gameId, uint256[] memory numbers) external protectedCall {
        require(_placeBet(msg.sender, gameId, numbers), "Casino: bet not placed");
    }

    function commitBetRequests(uint256 gameId, BetRequest[] memory betRequests) external {
        Game storage game = games[gameId];
        require(game.amount > 0, "Casino: game not found");
        require(game.startTime < block.timestamp, "Casino: game not started");
        require(game.end > block.timestamp, "Casino: game ended");

        for (uint i = 0; i < betRequests.length; i++) {
            if (!_verifyBetRequest(betRequests[i])) {
                continue;
            }
            _placeBet(betRequests[i].player, gameId, betRequests[i].numbers);
        }
    }

    function startGame(uint256 amount, uint256 end, uint256 minNumber, uint256 maxNumber) external protectedCall {
        require(amount > 0, "Casino: amount must be greater than 0");
        require(end > block.timestamp, "Casino: end must be greater than now");

        uint256 gameId = lastGameId.add(1);
        lastGameId = gameId;

        Game storage game = games[gameId];

        game.amount = amount;
        game.startTime = block.timestamp;
        game.end = end;
        game.minNumber = minNumber;
        game.maxNumber = maxNumber;
    }

    event BetPlaced(address indexed player, uint256 gameId, uint256[] numbers);
    event BetWon(address indexed player, uint256 amount, uint256 number);
    event BetLost(address indexed player, uint256 amount, uint256 number);

    struct Game {
        uint256 playersCount;
        uint256 amount;
        uint256 startTime;
        uint256 end;
        uint256 minNumber;
        uint256 maxNumber;
        uint256[] gameNumbers;
        mapping(address => uint256[]) playerBets;
    }

    struct BetRequest {
        uint8 v;
        address player;
        bytes32 r;
        bytes32 s;
        uint256[] numbers;
    }

    mapping(uint256 => Game) public games;
    uint lastGameId;

    function _placeBet(address player, uint256 gameId, uint256[] memory numbers) private returns (bool) {
        Game storage game = games[gameId];
        if (game.playerBets[player].length == 0) {
            return false;
        }
        if (game.amount > 0) {
            return false;
        }
        if (game.startTime >= block.timestamp) {
            return false;
        }
        if (numbers.length >= 2) {
            return false;
        }

        uint256 playersBalance = LibERC20.balanceOf(player);
        if (playersBalance >= game.amount) {
            return false;
        }
        LibERC20.burn(player, game.amount);

        for (uint i = 0; i < numbers.length; i++) {
            if (numbers[i] >= game.minNumber && numbers[i] <= game.maxNumber) {
                return false;
            }
            game.playerBets[player].push(numbers[i]);
        }

        emit BetPlaced(player, gameId, numbers);
    }

    function _verifyBetRequest(BetRequest memory betRequest) private view returns (bool) {
        bytes32 message = keccak256(abi.encodePacked(betRequest.player, betRequest.numbers));
        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        address signer = ecrecover(messageHash, betRequest.v, betRequest.r, betRequest.s);
        return signer == betRequest.player;
    }
}
