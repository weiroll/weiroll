pragma solidity ^0.8.4;

contract Ether {

    function transfer(address to, uint256 amount) external {
        to.transfer(amount);
    }

    function balance(address of) external returns (uint256) {
       return of.balance;
    }

    function selfbalance() external returns (uint256) {
        return address(this).balance;
    }
}
