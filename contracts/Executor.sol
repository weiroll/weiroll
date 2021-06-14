pragma solidity ^0.8.4;

uint8 constant VARIABLE_LENGTH = 0x80;
uint8 constant WORD_SIZE = 0x40;
uint8 constant FIXED_INDEX_MASK = 0x7f;
uint8 constant VARIABLE_INDEX_MASK = 0x3f;
uint8 constant END_OF_ARGS = 0xff;

contract Executor {
    event Executed(bytes result);

    function execute(bytes32[] calldata commands, bytes[] memory state)
        public
        returns (bytes[] memory)
    {
        for (uint256 i = 0; i < commands.length; i++) {
            bytes32 command = commands[i];
            address target = address(uint160(uint256(command)));
            bytes4 selector = bytes4(command);

            bytes memory input = buildInputs(
                selector,
                bytes6(command << 32),
                state
            );

            (bool success, bytes memory outdata) = target.delegatecall(input);
            require(success, "Call failed");

            writeOutputs(bytes2(command << 80), outdata, state);
        }
        emit Executed(state[0]);
        return state;
    }

    function buildInputs(
        bytes4 selector,
        bytes6 indices,
        bytes[] memory state
    ) public view returns (bytes memory ret) {
        uint256 count = 0; // Number of bytes in whole ABI encoded message
        uint256 free = 0; // Pointer to first free byte in tail part of message

        // Determine the length of the encoded data
        for (uint256 i = 0; i < 6; i++) {
            uint8 idx = uint8(indices[i]);
            if (idx == END_OF_ARGS) break;

            if (idx & VARIABLE_LENGTH != 0) {
                // Add the size of the value, rounded up to the next word boundary, plus space for pointer and length
                uint256 arglen = state[idx & VARIABLE_INDEX_MASK].length;
                count += ((arglen + 31) / 32) * 32 + 64;
                free += 32;
            } else {
                require(state[idx & FIXED_INDEX_MASK].length <= 32);
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
        for (uint256 i = 0; i < 6; i++) {
            uint8 idx = uint8(indices[i]);
            if (idx == END_OF_ARGS) break;

            if (idx & VARIABLE_LENGTH != 0) {
                uint256 arglen = state[idx & VARIABLE_INDEX_MASK].length;
                uint256 elementCount = arglen;
                if (idx & WORD_SIZE != 0) {
                    elementCount /= 32;
                }

                // Variable length data; put a pointer in the slot and write the data at the end
                assembly {
                    mstore(add(add(ret, 36), count), free)
                    mstore(add(add(ret, 36), free), elementCount)
                }
                memcpy(
                    state[idx & VARIABLE_INDEX_MASK],
                    0,
                    ret,
                    free + 36,
                    arglen
                );
                free += arglen + 32;
                count += 32;
            } else {
                // Fixed length data; write it directly
                bytes memory statevar = state[idx & FIXED_INDEX_MASK];
                assembly {
                    mstore(add(add(ret, 36), count), mload(add(statevar, 32)))
                }
                count += 32;
            }
        }
    }

    function writeOutputs(
        bytes2 indices,
        bytes memory output,
        bytes[] memory state
    ) internal view {
        for (uint256 j = 0; j < 2; j++) {
            uint8 idx = uint8(indices[j]);
            if (idx == END_OF_ARGS) break;

            if (idx & VARIABLE_LENGTH != 0) {
                uint256 argptr;
                uint256 elementCount;
                assembly {
                    argptr := mload(add(add(output, 32), mul(j, 32)))
                    elementCount := mload(add(add(output, 32), argptr))
                }
                uint256 arglen = (idx & WORD_SIZE != 0)
                    ? elementCount * 32
                    : elementCount;
                bytes memory newstate = new bytes(arglen);
                memcpy(output, argptr + 32, newstate, 0, arglen);
                state[idx & VARIABLE_INDEX_MASK] = newstate;
            } else {
                // Single word
                if (state[idx & FIXED_INDEX_MASK].length != 32) {
                    state[idx & FIXED_INDEX_MASK] = new bytes(32);
                }
                assembly {
                    let stateptr := mload(
                        add(add(state, 32), mul(and(idx, FIXED_INDEX_MASK), 32))
                    )
                    let word := mload(add(add(output, 32), mul(j, 32)))
                    mstore(add(stateptr, 32), word)
                }
            }
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
