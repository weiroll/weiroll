pragma solidity ^0.8.4;

contract Ether {
    function transfer(address payable to, uint256 amount) external {
        to.transfer(amount);
    }

    function balance(address addr) external view returns (uint256) {
        return addr.balance;
    }

    function selfbalance() external view returns (uint256) {
        return address(this).balance;
    }
}
