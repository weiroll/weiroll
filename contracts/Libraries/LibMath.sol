pragma solidity ^0.8.4;

contract LibMath {
    function add(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) external pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) external pure returns (uint256) {
        return a * b;
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
