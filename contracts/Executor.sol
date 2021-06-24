pragma solidity ^0.8.4;

import "./CommandBuilder.sol";

uint8 constant CT_DELEGATECALL = 0x00;
uint8 constant CT_CALL = 0x01;
uint8 constant CT_STATICCALL = 0x02;
uint8 constant CT_VALUECALL = 0x03;

uint8 constant COMMAND_CALLTYPE_MASK = 0x3;
uint8 constant COMMAND_EXTENDED_MASK = 0x80;
uint8 constant COMMAND_TUPLE_RETURN = 0x40;

uint8 constant NO_VALUE = 0xff;

uint256 constant SHORT_COMMAND_MASK = 0x000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

contract Executor {
    using CommandBuilder for bytes[];

    function execute(bytes32[] calldata commands, bytes[] memory state)
        public
        returns (bytes[] memory)
    {
        for (uint256 i = 0; i < commands.length; i++) {
            bytes32 command = commands[i];
            uint8 flags = uint8(bytes1(command << 32));
            bytes32 indices;

            bool success;
            bytes memory outdata;

            if (flags & COMMAND_EXTENDED_MASK != 0) {
                // check for i+1 >= commands.length here?
                indices = commands[i + 1];
                i += 1;
            } else {
                indices = bytes32(uint256(command << 40) | SHORT_COMMAND_MASK);
            }

            if (flags & COMMAND_CALLTYPE_MASK == CT_DELEGATECALL) {
                (success, outdata) = address(uint160(uint256(command))) // target
                .delegatecall(
                    // inputs
                    state.buildInputs(
                        //selector
                        bytes4(command),
                        indices
                    )
                );
            } else if (flags & COMMAND_CALLTYPE_MASK == CT_CALL) {
                (success, outdata) = address(uint160(uint256(command))).call( // target
                    // inputs
                    state.buildInputs(
                        //selector
                        bytes4(command),
                        indices
                    )
                );
            } else if (flags & COMMAND_CALLTYPE_MASK == CT_STATICCALL) {
                (success, outdata) = address(uint160(uint256(command))) // target
                .staticcall(
                    // inputs
                    state.buildInputs(
                        //selector
                        bytes4(command),
                        indices
                    )
                );
            } else if (flags & COMMAND_CALLTYPE_MASK == CT_VALUECALL) {
                uint256 calleth;
                bytes memory v = state[uint8(bytes1(indices))];
                assembly {
                    mstore(calleth, add(v, 0x20))
                }
                (success, outdata) = address(uint160(uint256(command))).call{ // target
                    value: calleth
                }(
                    // inputs
                    state.buildInputs(
                        //selector
                        bytes4(command),
                        bytes32(uint256(indices << 8) | NO_VALUE)
                    )
                );
            } else {
                revert("Invalid calltype");
            }

            require(success, "Call failed");

            if (
                flags & COMMAND_TUPLE_RETURN != 0 &&
                bytes1(command << 88) != bytes1(NO_VALUE)
            ) {
                uint8 idx = uint8(bytes1(command << 88));
                bytes memory entry = state[idx] = new bytes(
                    outdata.length + 32
                );
                CommandBuilder.memcpy(outdata, 0, entry, 32, outdata.length);
                assembly {
                    let l := mload(outdata)
                    mstore(add(entry, 32), l)
                }
            } else {
                state = state.writeOutputs(bytes1(command << 88), outdata);
            }
        }
        return state;
    }
}
