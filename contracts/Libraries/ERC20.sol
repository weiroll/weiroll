pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20Ops {
    function totalSupply(address token) external view returns (uint256) {
        return IERC20(token).totalSupply();
    }

    function balanceOf(address token, address account)
        external
        view
        returns (uint256)
    {
        return IERC20(token).balanceOf(account);
    }

    function transfer(
        address token,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        return IERC20(token).transfer(recipient, amount);
    }

    function allowance(
        address token,
        address owner,
        address spender
    ) external view returns (uint256) {
        return IERC20(token).allowance(owner, spender);
    }

    function approve(
        address token,
        address spender,
        uint256 amount
    ) external returns (bool) {
        return IERC20(token).approve(spender, amount);
    }

    function transferFrom(
        address token,
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        return IERC20(token).transferFrom(sender, recipient, amount);
    }
}
