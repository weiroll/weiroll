pragma solidity ^0.8.4;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

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
