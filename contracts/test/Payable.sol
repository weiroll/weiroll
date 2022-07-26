// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "hardhat/console.sol";

contract Payable {
    function pay() public payable returns (uint256) {
        return msg.value;
    }
}
