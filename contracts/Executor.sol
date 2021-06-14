pragma solidity ^0.8.4;

/**
 * @dev Executes scripts, defined as a series of delegatecall operations.
 *      Each command is packed as [bytes4 selector, bytes6 callindexes, bytes2 returnindexes, address target].
 *      Call and return indexes specify indexes into the global 'state' array. Before calling a command, its
 *      call data is constructed by ABI-encoding the specified call indexes. The most significant bit of each
 *      index indicates if the indexed data is fixed- or variable- length. If it is fixed-length, it is inserted
 *      directly into the ABI encoding. If it is variable-length, a pointer value is written in its place and the
 *      data itself is appended to the end. Fixed-length values can be literal values such as uint, byte32, etc,
 *      while variable length values should be the 'tail' part of ABI-encoded data - for example, in the case of
 *      a uint array it would be the 32 byte length value followed by the array elements.
 *      Return values are treated likewise and unpacked into the specified slots.
 * 
 *      0xFF is reserved as an index value for both call and return data; in either case it causes nothing to be
 *      read or written for that element.
 */
contract Executor {
    event Executed(bytes result);

    function execute(bytes32[] calldata commands, bytes[] memory state) public returns(bytes[] memory) {
        for(uint i = 0; i < commands.length; i++) {
            bytes32 command = commands[i];
            address target = address(uint160(uint256(command)));
            bytes4 selector = bytes4(command);

            bytes memory input = buildInputs(selector, bytes6(command << 32), state);

            (bool success, bytes memory outdata) = target.delegatecall(input);
            require(success, "Call failed");

            writeOutputs(bytes2(command << 80), outdata, state);
        }
        emit Executed(state[0]);
        return state;
    }
    
    function buildInputs(bytes4 selector, bytes6 indices, bytes[] memory state) public view returns(bytes memory ret) {
        uint count = 0; // Number of bytes in whole ABI encoded message
        uint free = 0; // Pointer to first free byte in tail part of message

        // Determine the length of the encoded data
        for(uint i = 0; i < 6; i++) {
            uint8 idx = uint8(indices[i]);
            if(idx == 0xFF) break;

            
            if(idx & 0x80 != 0) {
                // Add the size of the value, rounded up to the next word boundary, plus space for pointer and length
                uint arglen = state[idx & 0x3F].length;
                count += ((arglen + 31) / 32) * 32 + 64;
                free += 32;
            } else {
                require(state[idx & 0x7F].length <= 32);
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
        for(uint i = 0; i < 6; i++) {
            uint8 idx = uint8(indices[i]);
            if(idx == 0xFF) break;

            if(idx & 0x80 != 0) {
                uint arglen = state[idx & 0x3F].length;
                uint elementCount = arglen;
                if(idx & 0x40 != 0) {
                    elementCount /= 32;
                }
            
                // Variable length data; put a pointer in the slot and write the data at the end
                assembly {
                    mstore(add(add(ret, 36), count), free)
                    mstore(add(add(ret, 36), free), elementCount)
                }
                memcpy(state[idx & 0x3f], 0, ret, free + 36, arglen);
                free += arglen + 32;
                count += 32;
            } else {
                // Fixed length data; write it directly
                bytes memory statevar = state[idx & 0x7f];
                assembly {
                    mstore(add(add(ret, 36), count), mload(add(statevar, 32)))
                }
                count += 32;
            }
        }
    }
    
    function writeOutputs(bytes2 indices, bytes memory output, bytes[] memory state) internal view {
        for(uint j = 0; j < 2; j++) {
            uint8 idx = uint8(indices[j]);
            if(idx == 0xFF) break;

            if(idx & 0x80 != 0) {
                uint argptr;
                uint elementCount;
                assembly {
                    argptr := mload(add(add(output, 32), mul(j, 32)))
                    elementCount  := mload(add(add(output, 32), argptr))
                }
                uint arglen = (idx & 0x40 != 0) ? elementCount * 32 : elementCount;
                bytes memory newstate = new bytes(arglen);
                memcpy(output, argptr + 32, newstate, 0, arglen);
                state[idx & 0x3f] = newstate;
            } else {
                // Single word
                if(state[idx & 0x7f].length != 32) {
                    state[idx & 0x7f] = new bytes(32);
                }
                assembly {
                    let stateptr := mload(add(add(state, 32), mul(and(idx, 0x7f), 32)))
                    let word := mload(add(add(output, 32), mul(j, 32)))
                    mstore(add(stateptr, 32), word)
                }
            }
        }
    }
    
    function memcpy(bytes memory src, uint srcidx, bytes memory dest, uint destidx, uint len) internal view {
        assembly {
            pop(staticcall(gas(), 4, add(add(src, 32), srcidx), len, add(add(dest, 32), destidx), len))
        }
    }
}