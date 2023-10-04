// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../libraries/LibDiamond.sol";
import "../../interfaces/IERC20Facet.sol";
import "./LibERC20Storage.sol";
import "./LibERC20.sol";
import "../shared/Access/CallProtection.sol";

contract ERC20ExtensionFacet is CallProtection {
    using SafeMath for uint256;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    
    function transferInternalEx(address _to, uint256 _amount) external returns (bool) {
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();
        if (es.presaleBalance[msg.sender] > 0) {
            uint256 presalePart = _amount;
            if (es.presaleBalance[msg.sender] < _amount) {
                presalePart = es.presaleBalance[msg.sender];
            }
            es.presaleBalance[msg.sender] = es.presaleBalance[msg.sender].sub(presalePart);
            es.presaleBalance[_to] = es.presaleBalance[_to].add(presalePart);
        }
        _transfer(msg.sender, _to, _amount);
        return true;
    }

    function unusedPresaleBalanceEx(address account) external view returns (uint256) {
        return LibERC20Storage.erc20Storage().presaleBalance[account];
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();

        es.balances[_from] = es.balances[_from].sub(_amount);
        es.balances[_to] = es.balances[_to].add(_amount);

        emit Transfer(_from, _to, _amount);
    }

    function setExchange(address exchange, bool isExchanage) external protectedCall {
        LibERC20Storage.erc20Storage().exchange[exchange] = isExchanage;
    }

    function sellableBalance(address acc) external view returns(uint256) {
        return LibERC20Storage.erc20Storage().sellableBalance[acc];
    }

    function removeToken(address token, address to, uint256 amount) external protectedCall {
        if (amount == 0) {
            amount = IERC20(token).balanceOf(address(this));
        }

        IERC20(token).transfer(to, amount);
    }

    // function blacklist(address acc, bool val) external protectedCall {
    //     LibERC20Storage.erc20Storage().blacklisted[acc] = val;
    // }
}
