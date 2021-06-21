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
}
