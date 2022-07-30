// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

contract Receiver {
    function receive(uint256 value) external payable returns (uint256) {
        require(value == msg.value, "receive: msg.value not sent.");
    }
}
