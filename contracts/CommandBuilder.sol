pragma solidity ^0.8.4;

uint8 constant VARIABLE_LENGTH = 0x80;
uint8 constant INDEX_MASK = 0x7f;
uint8 constant END_OF_ARGS = 0xff;
uint8 constant USE_STATE = 0xfe;

library CommandBuilder {

    function buildInputs(
        bytes[] memory state,
        bytes4 selector,
        bytes7 indices
    ) internal view returns (bytes memory ret) {
        uint256 count = 0; // Number of bytes in whole ABI encoded message
        uint256 free = 0; // Pointer to first free byte in tail part of message
        bytes memory stateData; // Optionally encode the current state if the call requires it

        // Determine the length of the encoded data
        for (uint256 i = 0; i < 7; i++) {
            uint8 idx = uint8(indices[i]);
            if (idx == END_OF_ARGS) break;

            if (idx & VARIABLE_LENGTH != 0) {
                if (idx == USE_STATE) {
                    if(stateData.length == 0) {
                        stateData = abi.encode(state);
                    }
                    count += stateData.length;
                    free += 32;
                } else {
                    // Add the size of the value, rounded up to the next word boundary, plus space for pointer and length
                    uint arglen = state[idx & INDEX_MASK].length;
                    require(arglen % 32 == 0, "Dynamic state variables must be a multiple of 32 bytes");
                    count += arglen + 32;
                    free += 32;
                }
            } else {
                require(state[idx & INDEX_MASK].length == 32, "Static state variables must be 32 bytes");
                count += 32;
                free += 32;
            }
        }

        // Encode it
        ret = new bytes(count + 4);
        assembly {
            mstore(add(ret, 32), selector)
        }
        count = 0;
        for (uint256 i = 0; i < 7; i++) {
            uint8 idx = uint8(indices[i]);
            if (idx == END_OF_ARGS) break;

            if (idx & VARIABLE_LENGTH != 0) {
                if (idx == USE_STATE) {
                    assembly {
                        mstore(add(add(ret, 36), count), free)
                    }
                    memcpy(stateData, 32, ret, free + 4, stateData.length - 32);
                    free += stateData.length - 32;
                    count += 32;
                } else {
                    uint256 arglen = state[idx & INDEX_MASK].length;

                    // Variable length data; put a pointer in the slot and write the data at the end
                    assembly {
                        mstore(add(add(ret, 36), count), free)
                    }
                    memcpy(
                        state[idx & INDEX_MASK],
                        0,
                        ret,
                        free + 4,
                        arglen
                    );
                    free += arglen;
                    count += 32;
                }
            } else {
                // Fixed length data; write it directly
                bytes memory statevar = state[idx & INDEX_MASK];
                assembly {
                    mstore(add(add(ret, 36), count), mload(add(statevar, 32)))
                }
                count += 32;
            }
        }
    }

    function writeOutputs(
        bytes[] memory state,
        bytes1 index,
        bytes memory output
    ) internal view returns(bytes[] memory) {
        uint8 idx = uint8(index);
        if (idx == END_OF_ARGS) return state;

        if (idx == USE_STATE) {
            state = abi.decode(output, (bytes[]));
        } else if (idx & VARIABLE_LENGTH != 0) {
            // Check the first field is 0x20 (because we have only a single return value)
            // And copy the rest into state.
            uint256 argptr;
            assembly {
                argptr := mload(add(output, 32))
            }
            require(argptr == 32, "Only one return value permitted");
            bytes memory newstate = new bytes(output.length - 32);
            memcpy(output, 32, newstate, 0, newstate.length);
            state[idx & INDEX_MASK] = newstate;
        } else {
            // Single word
            require(output.length == 32, "Only one return value permitted");

            if (state[idx & INDEX_MASK].length != 32) {
                state[idx & INDEX_MASK] = new bytes(32);
            }
            assembly {
                let stateptr := mload(
                    add(add(state, 32), mul(and(idx, INDEX_MASK), 32))
                )
                let word := mload(add(output, 32))
                mstore(add(stateptr, 32), word)
            }
        }

        return state;
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
