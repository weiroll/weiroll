pragma solidity ^0.8.4;

import "./CommandBuilder.sol";

contract CommandBuilderHarness {

    using CommandBuilder for bytes[];

    event BuiltInput(address target, bytes input);

    function testBuildInputs(bytes32[] calldata commands, bytes[] memory state) public {
        for (uint256 i = 0; i < commands.length; i++) {
            bytes32 command = commands[i];
            address target = address(uint160(uint256(command)));
            bytes4 selector = bytes4(command);

            bytes memory input = state.buildInputs(
                selector,
                bytes6(command << 32)
            );

            emit BuiltInput(target, input);
        }
    }
}
