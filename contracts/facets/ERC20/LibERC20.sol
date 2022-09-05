// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LibERC20Storage.sol";
import "../../libraries/LibDiamond.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library LibERC20 {
    using SafeMath for uint256;

    // Need to include events locally because `emit Interface.Event(params)` does not work
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function initialize() internal {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();

        require(bytes(es.name).length == 0 && bytes(es.symbol).length == 0, "ALREADY_INITIALIZED");

        require(msg.sender == ds.contractOwner, "Must own the contract.");

        LibERC20.mint(msg.sender, 1000000 * 1e18, false);

        es.name = "C250GoldT";
        es.symbol = "CGOLDT";
    }

    function initialized() internal view returns (bool) {
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();
        return (bytes(es.name).length > 0 && bytes(es.symbol).length > 0);
    }

    function mint(address _to, uint256 _amount, bool _isInternal) internal {
        require(_to != address(0), "INVALID_TO_ADDRESS");

        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();

        if (es.totalSupply.add(_amount) > 1000000000 * 1e18) {
            _amount = 1000000000 * 1e18 - es.totalSupply;
        }
        require(_amount > 0, "MINT_ZERO_AMOUNT");

        es.balances[_to] = es.balances[_to].add(_amount);
        es.totalSupply = es.totalSupply.add(_amount);

        if(_isInternal) {

            es.presaleBalance[_to] = es.presaleBalance[_to].add(_amount);
        }
        emit Transfer(address(0), _to, _amount);
    }

    function burn(address _from, uint256 _amount) internal {
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();

        es.balances[_from] = es.balances[_from].sub(_amount);
        es.totalSupply = es.totalSupply.sub(_amount);

        if (es.presaleBalance[msg.sender] > 0) {
            uint256 presalePart = _amount;
            if (es.presaleBalance[msg.sender] < _amount) {
                presalePart = es.presaleBalance[msg.sender];
            }
            es.presaleBalance[msg.sender] = es.presaleBalance[msg.sender].sub(presalePart);
        }
        emit Transfer(_from, address(0), _amount);
    }

    function balanceOf(address _of) internal view returns (uint256) {
        return LibERC20Storage.erc20Storage().balances[_of];
    }
}
