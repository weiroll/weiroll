pragma solidity ^0.8.4;

import "./CommandBuilder.sol";

interface RawCall {
    function rawcall(bytes32 command, bytes32[] calldata staticState, bytes[] memory dynamicState)
        external
        returns (bytes32[] memory, bytes[] memory);
}

contract Executor {
    event Executed(bytes32 staticResult, bytes dynamicResult);

    function execute(bytes32[] calldata commands, bytes32[] memory staticState, bytes[] memory dynamicState)
        public
        returns (bytes32[] memory, bytes[] memory)
    {
        for (uint256 i = 0; i < commands.length; i++) {
            bytes32 command = commands[i];
            address target = address(uint160(uint256(command)));
            bytes4 selector = bytes4(command);

            if (selector == RawCall.rawcall.selector) {
                (bool success, bytes memory outdata) = target.delegatecall(
                    abi.encodeWithSelector(
                        RawCall.rawcall.selector,
                        command,
                        staticState,
                        dynamicState
                    )
                );
                require(success, "Rawcall failed");

                (staticState, dynamicState) = abi.decode(outdata, (bytes32[], bytes[]));
            } else {
                bytes memory input = CommandBuilder.buildInputs(
                    staticState,
                    dynamicState,
                    selector,
                    bytes7(command << 32)
                );

                (bool success, bytes memory outdata) = target.delegatecall(
                    input
                );
                require(success, "Call failed");

                CommandBuilder.writeOutput(staticState, dynamicState, bytes1(command << 88), outdata);
            }
        }
        emit Executed(staticState.length == 0 ? bytes32(0) : staticState[0], dynamicState.length == 0 ? bytes("") : dynamicState[0]);
        return (staticState, dynamicState);
    }
}
