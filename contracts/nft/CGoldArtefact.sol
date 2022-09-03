// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CGoldArtefact is ERC1155, Ownable {
  using SafeMath for uint;

  IERC20 cgold;

  mapping(uint256 => uint256) prize;
  mapping(uint256 => uint256) public supplies;
  uint256 constant MAX_SUPPLY = 100;
  uint256 public totalSupply;

  constructor(string memory _uri, address _cgold) ERC1155(_uri) {
    cgold = IERC20(_cgold);
  }

  function name() external pure returns (string memory) {
    return "CGoldArtefact";
  }

  function symbol() external pure returns (string memory) {
    return "CGOLDA";
  }

  function mint(uint256 _tokenID, uint256 _quantity, address _ref) external {
    require(prize[_tokenID] > 0, "NOT_MINTING");
    require(supplies[_tokenID].add(_quantity) < MAX_SUPPLY);

    uint256 amount = _quantity.mul(prize[_tokenID]);
    require(cgold.balanceOf(msg.sender) >= amount, "ACCOUNT_NOT_FUNDED");
    cgold.transferFrom(msg.sender, address(this), amount);
    if(_ref != msg.sender && _ref != address(0)) {
      cgold.transfer(_ref, amount.div(10));
    }
    _mint(msg.sender, _tokenID, _quantity, "");
    supplies[_tokenID] = supplies[_tokenID].add(_quantity);
    totalSupply = totalSupply.add(1);
  }

  function retrieveProceed() external onlyOwner {
    cgold.transfer(msg.sender, cgold.balanceOf(address(this)));
  }

  function setPrize(uint256 _tokenID, uint256 _prize) external onlyOwner {
    prize[_tokenID] = _prize;
  }
}