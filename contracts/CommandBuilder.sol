// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

library CommandBuilder {

    uint256 constant IDX_VARIABLE_LENGTH = 0x80;
    uint256 constant IDX_VALUE_MASK = 0x7f;
    uint256 constant IDX_END_OF_ARGS = 0xff;
    uint256 constant IDX_USE_STATE = 0xfe;

    // Error selectors used in assembly revert blocks:
    // InvalidDynamicLength() = 0xbad2f669
    // InvalidStaticLength()  = 0xb4fa3fb3
    // InvalidReturnVariable() = 0x09bad878
    // InvalidReturnStatic()  = 0x71c4efc1

    function buildInputs(
        bytes[] memory state,
        bytes4 selector,
        bytes32 indices
    ) internal view returns (bytes memory ret) {
        uint256 count; // Number of bytes in whole ABI encoded message
        uint256 free; // Pointer to first free byte in tail part of message
        bytes memory stateData; // Optionally encode the current state if the call requires it

        uint256 idx;

        // Determine the length of the encoded data
        // This first loop only counts, no encoding
        for (uint256 i; i < 32;) {
            assembly { idx := byte(i, indices) }
            if (idx == IDX_END_OF_ARGS) break;

            if (idx & IDX_VARIABLE_LENGTH != 0) {
                if (idx == IDX_USE_STATE) {
                    if (stateData.length == 0) {
                        stateData = abi.encode(state);
                    }
                    unchecked { count += stateData.length; }
                } else {
                    uint256 arglen;
                    assembly {
                        let stateElement := mload(add(add(state, 32), shl(5, and(idx, 0x7f))))
                        arglen := mload(stateElement)
                        if and(arglen, 31) {
                            // revert InvalidDynamicLength()
                            mstore(0, 0xbad2f66900000000000000000000000000000000000000000000000000000000)
                            revert(0, 4)
                        }
                    }
                    unchecked { count += arglen + 32; }
                }
            } else {
                // For static args we just need to verify length and add 32
                assembly {
                    let stateElement := mload(add(add(state, 32), shl(5, and(idx, 0x7f))))
                    let arglen := mload(stateElement)
                    if iszero(eq(arglen, 32)) {
                        // revert InvalidStaticLength()
                        mstore(0, 0xb4fa3fb300000000000000000000000000000000000000000000000000000000)
                        revert(0, 4)
                    }
                }
                unchecked { count += 32; }
            }
            unchecked{free += 32;}
            unchecked{++i;}
        }

        // Encode it - use assembly allocation to skip memory zeroing
        assembly {
            let size := add(count, 4)
            ret := mload(0x40)
            mstore(ret, size)
            // Update free memory pointer (length word + data, rounded up to 32)
            mstore(0x40, add(add(ret, 32), and(add(size, 31), not(31))))
            mstore(add(ret, 32), selector)
        }
        count = 0;
        for (uint256 i; i < 32;) {
            assembly { idx := byte(i, indices) }
            if (idx == IDX_END_OF_ARGS) break;

            if (idx & IDX_VARIABLE_LENGTH != 0) {
                if (idx == IDX_USE_STATE) {
                    assembly {
                        mstore(add(add(ret, 36), count), free)
                    }
                    unchecked {
                        memcpy(stateData, 32, ret, free + 4, stateData.length - 32);
                        free += stateData.length - 32;
                    }
                } else {
                    bytes memory stateElement;
                    uint256 arglen;
                    assembly {
                        stateElement := mload(add(add(state, 32), shl(5, and(idx, 0x7f))))
                        arglen := mload(stateElement)
                    }

                    assembly {
                        mstore(add(add(ret, 36), count), free)
                    }
                    unchecked {
                        memcpy(
                            stateElement,
                            0,
                            ret,
                            free + 4,
                            arglen
                        );
                        free += arglen;
                    }
                }
            } else {
                // Fixed length data; write it directly
                assembly {
                    let stateElement := mload(add(add(state, 32), shl(5, and(idx, 0x7f))))
                    mstore(add(add(ret, 36), count), mload(add(stateElement, 32)))
                }
            }
            unchecked{count += 32;}
            unchecked{++i;}
        }
    }

    function writeOutputs(
        bytes[] memory state,
        bytes1 index,
        bytes memory output
    ) internal pure returns (bytes[] memory) {
        uint256 idx = uint8(index);
        if (idx == IDX_END_OF_ARGS) return state;

        if (idx & IDX_VARIABLE_LENGTH != 0) {
            if (idx == IDX_USE_STATE) {
                state = abi.decode(output, (bytes[]));
            } else {
                assembly {
                    // Check the first field is 0x20 (because we have only a single return value)
                    if iszero(eq(mload(add(output, 32)), 32)) {
                        mstore(0, 0x09bad87800000000000000000000000000000000000000000000000000000000)
                        revert(0, 4)
                    }
                    // Overwrite the first word of the return data with the length - 32
                    mstore(add(output, 32), sub(mload(output), 32))
                    // Insert a pointer to the return data, starting at the second word, into state
                    mstore(
                        add(add(state, 32), shl(5, and(idx, IDX_VALUE_MASK))),
                        add(output, 32)
                    )
                }
            }
        } else {
            // Single word - check length and write in one assembly block
            assembly {
                if iszero(eq(mload(output), 32)) {
                    mstore(0, 0x71c4efc100000000000000000000000000000000000000000000000000000000)
                    revert(0, 4)
                }
                mstore(
                    add(add(state, 32), shl(5, and(idx, IDX_VALUE_MASK))),
                    output
                )
            }
        }

        return state;
    }

    function writeTuple(
        bytes[] memory state,
        bytes1 index,
        bytes memory output
    ) internal view {
        uint256 idx = uint256(uint8(index));
        if (idx == IDX_END_OF_ARGS) return;

        bytes memory entry;
        // Allocate without zeroing and write to state array in one assembly block
        assembly {
            let size := add(mload(output), 32)
            entry := mload(0x40)
            mstore(entry, size)
            mstore(0x40, add(add(entry, 32), and(add(size, 31), not(31))))
            // Write entry to state[idx]
            mstore(add(add(state, 32), shl(5, idx)), entry)
        }
        memcpy(output, 0, entry, 32, output.length);
        assembly {
            let l := mload(output)
            mstore(add(entry, 32), l)
        }
    }

    function memcpy(
        bytes memory src,
        uint256 srcidx,
        bytes memory dest,
        uint256 destidx,
        uint256 len
    ) internal view {
        assembly {
            pop(
                staticcall(
                    gas(),
                    4,
                    add(add(src, 32), srcidx),
                    len,
                    add(add(dest, 32), destidx),
                    len
                )
            )
        }
    }
}
