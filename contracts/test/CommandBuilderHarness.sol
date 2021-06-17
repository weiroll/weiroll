pragma solidity ^0.8.4;

import "../CommandBuilder.sol";

contract CommandBuilderHarness {
    using CommandBuilder for bytes[];

    event BuiltOutput(bytes[] state, bytes output);

    function testBuildInputs(
        bytes[] memory state,
        bytes4 selector,
        bytes7 indices
    ) public view returns (bytes memory){
        bytes memory input = state.buildInputs(selector, indices);

        return input;
    }

    function testWriteOutputs(
        bytes[] memory state,
        bytes1 index,
        bytes memory output
    ) public view returns (bytes[] memory, bytes memory) {
        state = state.writeOutputs(index, output);

        return (state, output);
    }
}
