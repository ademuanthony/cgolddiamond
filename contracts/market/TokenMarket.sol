// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author:Ademu Anthony (https://twitter.com/Oxa2e)
/******************************************************************************/

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenMarket is Ownable {   
  using SafeMath for uint256; 

  uint256 public rate;
  uint256 public divisor;
  address token;

  constructor(address _token, uint256 _rate, uint256 _divisor) {
    token = _token;
    rate = _rate;
    divisor = _divisor;
  }

  function setRate(uint256 _rate, uint256 _divisor) external onlyOwner {
    rate = _rate;
    divisor = _divisor;
  }

  function setToken(address _token) external onlyOwner {
    token = _token;
  }
  
  function buy() payable external {
    require(msg.value > 0, "ZERO VALUE");

    payable(owner()).transfer(msg.value);
    uint256 amount = rate.mul(msg.value).div(divisor);
    IERC20(token).transfer(msg.sender, amount);
  }

  function closeSales() external onlyOwner {
    uint256 amount = IERC20(token).balanceOf(address(this));
    if(amount > 0) {
      IERC20(token).transfer(owner(), amount);
    }
  }
}