pragma solidity ^0.8.4;

import "./CommandBuilder.sol";

interface RawCall {
    function rawcall(bytes32 command, bytes[] memory state) external returns (bytes[] memory);
}

contract Executor {
    event Executed(bytes result);

    using CommandBuilder for bytes[];

    function execute(bytes32[] calldata commands, bytes[] memory state)
        public
        returns (bytes[] memory)
    {
        for (uint256 i = 0; i < commands.length; i++) {
            bytes32 command = commands[i];
            address target = address(uint160(uint256(command)));
            bytes4 selector = bytes4(command);

            if (selector == RawCall.rawcall.selector){
                (bool success, bytes memory outdata) =
                    target.delegatecall(abi.encodeWithSelector(RawCall.rawcall.selector, command, state));
                require(success, "Rawcall failed");

                state = abi.decode(outdata, (bytes[]));
            }
            else {
                bytes memory input = state.buildInputs(
                    selector,
                    bytes6(command << 32)
                );

                (bool success, bytes memory outdata) = target.delegatecall(input);
                require(success, "Call failed");

                state.writeOutputs(bytes2(command << 80), outdata);
            }

        }
        emit Executed(state[0]);
        return state;
    }

}
