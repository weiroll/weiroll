// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "hardhat/console.sol";

contract Payable {
    function pay() public payable {}

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
