// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./CommandBuilder.sol";

uint8 constant FLAG_CT_DELEGATECALL = 0x00;
uint8 constant FLAG_CT_CALL = 0x01;
uint8 constant FLAG_CT_STATICCALL = 0x02;
uint8 constant FLAG_CT_VALUECALL = 0x03;
uint8 constant FLAG_CT_MASK = 0x03;
uint8 constant FLAG_EXTENDED_COMMAND = 0x80;
uint8 constant FLAG_TUPLE_RETURN = 0x40;

uint256 constant SHORT_COMMAND_FILL = 0x000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

contract VM {
    using CommandBuilder for bytes[];

    address immutable self;

    error ExecutionFailed(
        uint256 command_index,
        address target,
        string message
    );

    modifier ensureDelegateCall() {
        require(address(this) != self);
        _;
    }

    constructor() {
        self = address(this);
    }

    function execute(bytes32[] calldata commands, bytes[] memory state)
        public
        ensureDelegateCall
        returns (bytes[] memory)
    {
        bytes32 command;
        uint256 flags;
        bytes32 indices;

        bool success;
        bytes memory outdata;

        for (uint256 i = 0; i < commands.length; i++) {
            command = commands[i];
            flags = uint8(bytes1(command << 32));

            if (flags & FLAG_EXTENDED_COMMAND != 0) {
                indices = commands[i++];
            } else {
                indices = bytes32(uint256(command << 40) | SHORT_COMMAND_FILL);
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
                        bytes32(uint256(indices << 8) | IDX_END_OF_ARGS)
                    )
                );
            } else {
                revert("Invalid calltype");
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
        }
        return state;
    }
}
