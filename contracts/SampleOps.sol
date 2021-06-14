pragma solidity ^0.8.4;

contract SampleOps {
    function add(uint a, uint b) external pure returns(uint) {
        return a + b;
    }

    function strlen(string calldata x) external pure returns(uint) {
        return bytes(x).length;
    }

    function strcat(bytes calldata a, bytes calldata b) external pure returns(bytes memory) {
        return abi.encodePacked(a, b);
    }

    function sum(uint[] calldata values) external pure returns(uint ret) {
        for(uint i = 0; i < values.length; i++) {
            ret += values[i];
        }
    }
}
