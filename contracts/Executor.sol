pragma solidity ^0.8.4;

import "./CommandBuilder.sol";

contract Executor {
    using CommandBuilder for bytes[];

    function _execute(bytes32[] calldata commands, bytes[] memory state)
        internal
        returns (bytes[] memory)
    {
        for (uint256 i = 0; i < commands.length; i++) {
            bytes32 command = commands[i];

            (
                bool success,
                bytes memory outdata // target
            ) = address(uint160(uint256(command))).delegatecall(
                // inputs
                state.buildInputs(
                    //selector
                    bytes4(command),
                    bytes7(command << 32)
                )
            );

            require(success, "Call failed");
            state = state.writeOutputs(bytes1(command << 88), outdata);
        }
        return state;
    }
}
