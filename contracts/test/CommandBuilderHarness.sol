pragma solidity ^0.8.4;

import "../CommandBuilder.sol";

contract CommandBuilderHarness {
    using CommandBuilder for bytes[];

    event BuiltInput(bytes input);
    event BuiltOutput(bytes[] state, bytes output);

    function testBuildInputs(
        bytes[] memory state,
        bytes4 selector,
        bytes7 indices
    ) public {
        bytes memory input = state.buildInputs(selector, indices);

        emit BuiltInput(input);
    }

    function testWriteOutputs(
        bytes[] memory state,
        bytes1 index,
        bytes memory output
    ) public {
        state.writeOutputs(index, output);

        emit BuiltOutput(state, output);
    }
}
