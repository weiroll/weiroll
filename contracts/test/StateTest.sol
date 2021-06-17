pragma solidity ^0.8.4;

contract StateTest {
    function addSlots(uint dest, uint src, uint src2, bytes[] memory state) public pure returns(bytes[] memory) {
        state[dest] = abi.encode(abi.decode(state[src], (uint)) + abi.decode(state[src2], (uint)));
        return state;
    }
}
