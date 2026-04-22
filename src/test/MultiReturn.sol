// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

contract MultiReturn {
    event Calculated(uint256 j);

    function intTuple()
        public
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (0xbad, 0xdeed, 0xcafe);
    }

    function tupleConsumer(uint256 arg) public {
        emit Calculated(arg);
    }
}
