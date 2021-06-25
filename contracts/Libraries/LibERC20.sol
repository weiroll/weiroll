pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LibERC20 {
    function totalSupply(IERC20 token) external view returns (uint256) {
        return token.totalSupply();
    }

    function balanceOf(IERC20 token, address account)
        external
        view
        returns (uint256)
    {
        return token.balanceOf(account);
    }

    function transfer(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        return token.transfer(recipient, amount);
    }

    function allowance(
        IERC20 token,
        address owner,
        address spender
    ) external view returns (uint256) {
        return token.allowance(owner, spender);
    }

    function approve(
        IERC20 token,
        address spender,
        uint256 amount
    ) external returns (bool) {
        return token.approve(spender, amount);
    }

    function transferFrom(
        IERC20 token,
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        return token.transferFrom(sender, recipient, amount);
    }

    /* Weiroll script utility functions */

    function approveAndCall(
        IERC20 token,
        address target,
        uint256 amount,
        bytes calldata data
    ) external returns (bytes memory) {
        token.approve(target, amount);
        (bool success, bytes memory outdata) = target.call(data);
        require(success, "approveAndCall target.call reverted");
        token.approve(target, 0);
        return outdata;
    }

    function approveAndCallWithValue(
        IERC20 token,
        address target,
        uint256 amount,
        bytes calldata data,
        uint256 value
    ) external returns (bytes memory) {
        token.approve(target, amount);
        (bool success, bytes memory outdata) = target.call{value: value}(data);
        require(success, "approveAndCallWithValue target.call reverted");
        token.approve(target, 0);
        return outdata;
    }
}
