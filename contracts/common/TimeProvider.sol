/**
 *SPDX-License-Identifier: UNLICENSED
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract TimeProvider is Ownable {
    uint256 manualTime;

    function currentTime() external view returns (uint256 amountOut) {
        if (manualTime > 0) return manualTime;
        return block.timestamp;
    }

    function setTime(uint256 _now) onlyOwner external {
        manualTime = _now;
    }

    function increaseTime(uint256 val) onlyOwner external {
        if (manualTime > 0) {
            manualTime = manualTime + val;
        } else {
            manualTime = block.timestamp + val;
        }
    }

    function decreaseTime(uint256 val) onlyOwner external {
        if (manualTime > 0) {
            manualTime = manualTime - val;
        } else {
            manualTime = block.timestamp - val;
        }
    }

    function reset() onlyOwner external {
        manualTime = 0;
    }
}
