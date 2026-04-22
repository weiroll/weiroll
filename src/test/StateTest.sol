// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

contract StateTest {
    function addSlots(
        uint256 dest,
        uint256 src,
        uint256 src2,
        bytes[] memory state
    ) public pure returns (bytes[] memory) {
        state[dest] = abi.encode(
            abi.decode(state[src], (uint256)) +
                abi.decode(state[src2], (uint256))
        );
        return state;
    }
}
