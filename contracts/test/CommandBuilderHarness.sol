// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../CommandBuilder.sol";

contract CommandBuilderHarness {
    using CommandBuilder for bytes[];

    function basecall() public pure {}

    function testBuildInputsBaseGas(
        bytes[] memory state,
        bytes4 selector,
        bytes32 indices
    ) public view returns (bytes memory out) {}

    function testWriteOutputsBaseGas(
        bytes[] memory state,
        bytes1 index,
        bytes memory output
    ) public pure returns (bytes[] memory, bytes memory) {
        (index, output); // shh compiler
        return (state, new bytes(32));
    }

    function testBuildInputs(
        bytes[] memory state,
        bytes4 selector,
        bytes32 indices
    ) public view returns (bytes memory) {
        bytes memory input = state.buildInputs(selector, indices);

        return input;
    }

    function testWriteOutputs(
        bytes[] memory state,
        bytes1 index,
        bytes memory output
    ) public pure returns (bytes[] memory, bytes memory) {
        state = state.writeOutputs(index, output);

        return (state, output);
    }
}
