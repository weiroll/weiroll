// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

contract Math {
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
        uint256 valuesLength = values.length;
        for (uint256 i; i < valuesLength; ++i) {
            ret += values[i];
        }
    }

    function sumExtended(
      uint256 a, 
      uint256 b,
      uint256 c,
      uint256 d,
      uint256 e,
      uint256 f,
      uint256 g // 7 args will trigger extended
      
    )
        external
        pure
        returns (uint256 ret)
    {
      return a + b + c + d + e + f + g;
    }
}
