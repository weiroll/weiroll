// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./CommandBuilder.sol";


abstract contract VM {
    using CommandBuilder for bytes[];

    uint256 constant FLAG_CT_DELEGATECALL = 0x00;
    uint256 constant FLAG_CT_CALL = 0x01;
    uint256 constant FLAG_CT_STATICCALL = 0x02;
    uint256 constant FLAG_CT_VALUECALL = 0x03;
    uint256 constant FLAG_CT_MASK = 0x03;
    uint256 constant FLAG_EXTENDED_COMMAND = 0x80;
    uint256 constant FLAG_TUPLE_RETURN = 0x40;

    uint256 constant SHORT_COMMAND_FILL = 0x000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    address immutable self;

    error ExecutionFailed(
        uint256 command_index,
        address target,
        string message
    );

    constructor() {
        self = address(this);
    }

    function _execute(bytes32[] calldata commands, bytes[] memory state)
      internal returns (bytes[] memory)
    {
        bytes32 command;
        uint256 flags;
        bytes32 indices;

        bool success;
        bytes memory outdata;

        uint256 commandsLength = commands.length;
        for (uint256 i; i < commandsLength;) {
            command = commands[i];
            // Extract flags byte (byte 4 of command) using assembly
            assembly {
                flags := byte(4, command)
            }

            if (flags & FLAG_EXTENDED_COMMAND != 0) {
                unchecked { indices = commands[i++]; }
            } else {
                assembly {
                    indices := or(shl(40, command), SHORT_COMMAND_FILL)
                }
            }

            if (flags & FLAG_CT_MASK == FLAG_CT_DELEGATECALL) {
                (success, outdata) = address(uint160(uint256(command))).delegatecall( // target
                    // inputs
                    state.buildInputs(
                        //selector
                        bytes4(command),
                        indices
                    )
                );
            } else if (flags & FLAG_CT_MASK == FLAG_CT_CALL) {
                (success, outdata) = address(uint160(uint256(command))).call( // target
                    // inputs
                    state.buildInputs(
                        //selector
                        bytes4(command),
                        indices
                    )
                );
            } else if (flags & FLAG_CT_MASK == FLAG_CT_STATICCALL) {
                (success, outdata) = address(uint160(uint256(command))).staticcall( // target
                    // inputs
                    state.buildInputs(
                        //selector
                        bytes4(command),
                        indices
                    )
                );
            } else if (flags & FLAG_CT_MASK == FLAG_CT_VALUECALL) {
                uint256 calleth;
                bytes memory v;
                assembly {
                    v := mload(add(add(state, 32), mul(byte(0, indices), 32)))
                }
                if (v.length != 32) revert ExecutionFailed(i, address(uint160(uint256(command))), "no value");
                assembly {
                    calleth := mload(add(v, 0x20))
                }
                (success, outdata) = address(uint160(uint256(command))).call{ // target
                    value: calleth
                }(
                    // inputs
                    state.buildInputs(
                        //selector
                        bytes4(command),
                        bytes32(uint256(indices << 8) | CommandBuilder.IDX_END_OF_ARGS)
                    )
                );
            } else {
                revert ExecutionFailed(i, address(uint160(uint256(command))), "bad calltype");
            }

            if (!success) {
                if (outdata.length > 0) {
                    assembly {
                        outdata := add(outdata, 68)
                    }
                }
                revert ExecutionFailed({
                    command_index: 0,
                    target: address(uint160(uint256(command))),
                    message: outdata.length > 0 ? string(outdata) : "Unknown"
                });
            }

            if (flags & FLAG_TUPLE_RETURN != 0) {
                state.writeTuple(bytes1(command << 88), outdata);
            } else {
                state = state.writeOutputs(bytes1(command << 88), outdata);
            }
            unchecked{++i;}
        }
        return state;
    }
}
