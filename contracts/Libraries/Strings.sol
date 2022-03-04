// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

contract Strings {
    function strlen(string calldata x) external pure returns (uint256) {
        return bytes(x).length;
    }

    function strcat(string calldata a, string calldata b)
        external
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(a, b));
    }
}
