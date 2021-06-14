pragma solidity ^0.8.4;

contract SampleOps {
    function add(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b;
    }

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

    function sum(uint256[] calldata values)
        external
        pure
        returns (uint256 ret)
    {
        for (uint256 i = 0; i < values.length; i++) {
            ret += values[i];
        }
    }
}
