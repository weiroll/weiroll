pragma solidity ^0.8.4;

contract Strings {
    function strlen(string calldata x) external pure returns (uint256) {
        return bytes(x).length;
    }

    function strcat(bytes calldata a, bytes calldata b)
        external
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(a, b);
    }
}
