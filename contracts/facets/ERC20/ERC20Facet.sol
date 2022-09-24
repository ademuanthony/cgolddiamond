// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../libraries/LibDiamond.sol";
import "../../interfaces/IERC20Facet.sol";
import "./LibERC20Storage.sol";
import "./LibERC20.sol";
import "../shared/Access/CallProtection.sol";

contract ERC20Facet is IERC20, IERC20Facet, CallProtection {
    using SafeMath for uint256;

    function name() external view override returns (string memory) {
        return LibERC20Storage.erc20Storage().name;
    }

    function setName(string calldata _name) external override protectedCall {
        LibERC20Storage.erc20Storage().name = _name;
    }

    function symbol() external view override returns (string memory) {
        return LibERC20Storage.erc20Storage().symbol;
    }

    function setSymbol(string calldata _symbol) external override protectedCall {
        LibERC20Storage.erc20Storage().symbol = _symbol;
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function burn(address _from, uint256 _amount) external override protectedCall {
        LibERC20.burn(_from, _amount);
    }

    function approve(address _spender, uint256 _amount) external override returns (bool) {
        require(_spender != address(0), "SPENDER_INVALID");
        LibERC20Storage.erc20Storage().allowances[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    function increaseApproval(address _spender, uint256 _amount) external override returns (bool) {
        require(_spender != address(0), "SPENDER_INVALID");
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();
        es.allowances[msg.sender][_spender] = es.allowances[msg.sender][_spender].add(_amount);
        emit Approval(msg.sender, _spender, es.allowances[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval(address _spender, uint256 _amount) external override returns (bool) {
        require(_spender != address(0), "SPENDER_INVALID");
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();
        uint256 oldValue = es.allowances[msg.sender][_spender];
        if (_amount > oldValue) {
            es.allowances[msg.sender][_spender] = 0;
        } else {
            es.allowances[msg.sender][_spender] = oldValue.sub(_amount);
        }
        emit Approval(msg.sender, _spender, es.allowances[msg.sender][_spender]);
        return true;
    }

    function transfer(address _to, uint256 _amount) external override returns (bool) {
        // LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();
        // require(es.presaleBalance[msg.sender] < _amount, "INSUFFICIENT_AVAILABLE_BALANCE");
        _transfer(msg.sender, _to, _amount);
        return true;
    }
    function transferInternal(address _to, uint256 _amount) external returns (bool) {
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

    function unusedPresaleBalance(address account) external view returns (uint256) {
        return LibERC20Storage.erc20Storage().presaleBalance[account];
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) external override returns (bool) {
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();
        require(_from != address(0), "FROM_INVALID");
        require(es.allowances[_from][msg.sender] >= _amount, "INSUFFICIENT_ALLOWANCE");
        // require(es.presaleBalance[_from] < _amount, "INSUFFICIENT_AVAILABLE_BALANCE");

        // Update approval if not set to max uint256
        if (es.allowances[_from][msg.sender] != (2**256 - 1)) {
            uint256 newApproval = es.allowances[_from][msg.sender].sub(_amount);
            es.allowances[_from][msg.sender] = newApproval;
            emit Approval(_from, msg.sender, newApproval);
        }

        _transfer(_from, _to, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) external view override returns (uint256) {
        return LibERC20Storage.erc20Storage().allowances[_owner][_spender];
    }

    function balanceOf(address _of) external view override returns (uint256) {
        return LibERC20Storage.erc20Storage().balances[_of];
    }

    function totalSupply() external view override returns (uint256) {
        return LibERC20Storage.erc20Storage().totalSupply;
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
}
