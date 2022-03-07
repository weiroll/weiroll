// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

contract Sender {
    function sender() public view returns (address) {
        return msg.sender;
    }
}
