// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "hardhat/console.sol";

contract Payable {
    function pay() public payable {}

    function getBalance() public payable returns (uint256) {
      console.log("getBalance");
      console.log(address(this).balance);
        return address(this).balance;
    }
}
