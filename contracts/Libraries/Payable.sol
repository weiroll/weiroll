// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Payable {
    function pay() external payable {
    }

    function balance() external view returns (uint256) {
        return address(this).balance;
    }
}
