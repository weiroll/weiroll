object "Executor" {
    code {
        datacopy(0, dataoffset("runtime"), datasize("runtime"))
        setimmutable(0, "addr", address())
        return(0, datasize("runtime"))
    }
    object "runtime" {
        code {
            // Prevent non-delegatecalls
            if eq(loadimmutable("addr"), address()) {
                revert(0, 0)
            }

            // Free memory pointer
            mstore(0x20, memoryguard(0x40))

            switch selector()
            case 0xde792d5f { // execute(bytes32[], bytes[])
                execute()
            }
            default {
                revert(0, 0)
            }
            
            function selector() -> s {
                s := shr(224, calldataload(0))
            }

            function require(condition) {
                if iszero(condition) { revert(0, 0) }
            }
            
            // Allocates `amt` bytes of memory and returns a pointer to the first byte
            function malloc(amt) -> ptr {
                amt := mul(div(add(amt, 0x1F), 0x20), 0x20) // Round up to word boundary
                ptr := mload(0x20)
                mstore(0x20, add(ptr, amt))
            }
            
            // Copies `l` bytes of memory from `s` to `d`
            function memcpy(d, s, l) {
                pop(staticcall(gas(), 4, s, l, d, l))
            }
            
            // Loads a `bytes` from calldata at `cdp`, returning a pointer to memory
            function loadCalldataBytes(cdp) -> mp {
                let dataLen := calldataload(cdp)
                mp := malloc(add(dataLen, 0x20))
                calldatacopy(mp, cdp, add(dataLen, 0x20))
            }
            
            // Loads a `bytes[]` from calldata at `basePtr`, returning a pointer to memory
            function loadCalldataBytesArray(basePtr) -> statePtr {
                let stateLen := calldataload(basePtr)
                statePtr := malloc(mul(add(stateLen, 1), 0x20))
                mstore(statePtr, stateLen)
                for { let mp := statePtr let cdp := basePtr } gt(stateLen, 0) { stateLen := sub(stateLen, 1) } {
                    mp := add(mp, 0x20)
                    cdp := add(cdp, 0x20)
                    mstore(mp, loadCalldataBytes(add(add(basePtr, 0x20), calldataload(cdp))))
                }
            }
            
            // Scans an array of indices, returning the number of words required for the 'head'
            // part of ABI encoding.
            function getInputLength(indices) -> headlen {
                headlen := 0
                for { let i := 0 } lt(i, 32) { i := add(i, 1) } {
                    let idx := and(shr(sub(248, mul(i, 8)), indices), 0xFF)
                    if eq(idx, 0xFF) {
                        break
                    }
                    headlen := add(headlen, 32)
                }
            }

            // Returns a pointer to a state variable, allocating it if necessary
            // The returned value points to the word containing the length of the slot
            function getStateSlot(statePtr, index, len) -> argptr {
                let argptrptr := add(statePtr, mul(add(index, 1), 0x20))
                argptr := mload(argptrptr)
                if lt(mload(argptr), len) {
                    argptr := malloc(add(len, 0x20))
                    mstore(argptrptr, argptr)
                }
            }
            
            // ABI-encodes a set of function inputs, returning a memory pointer and size
            function buildInputs(statePtr, sel, indices) -> inptr, insize {
                let headlen := getInputLength(indices)
                inptr := mload(0x20)
                mstore(inptr, sel)
                
                let head := 0 // Offset of the head part of ABI encoding we're up to
                let tail := headlen // Offset of the tail part of ABI encoding we're up to
                // Iterate over each of the indices
                for { let i := 0 } lt(i, 32) { i := add(i, 1) } {
                    let idx := and(shr(sub(248, mul(i, 8)), indices), 0xFF)
                    switch and(idx, 0x80)
                    // Variable-length argument
                    case 0x80 {
                        if eq(idx, 0xFF) {
                            break
                        }

                        switch and(idx, 0xFF)

                        case 0xFE {
                            // Copy the state array into the encoding state.

                            // First calculate the location
                            let currentPtr := add(add(inptr, head), 4)
                            head := add(head, 0x20)
                            mstore(currentPtr, head)
                            let locationptr := add(currentPtr, 0x20)
                            // Store the length of the variable-size array
                            mstore(locationptr, mload(statePtr))
                            head := add(head, 0x20)
                            let totalBytes := 0
                            for { let j := 0 } lt(j, mload(statePtr)) { j := add(j,1)} {
                                // Pointer where the length of the bytes value at index j is stored.
                                let ptr := mload(add(statePtr, mul( add(j,1), 0x20)))
                                locationptr := add(locationptr, 0x20)
                                mstore(locationptr, add(mul(0x20, mload(statePtr)), totalBytes))
                                totalBytes := add(totalBytes, add(0x20, mload(ptr)))
                                head := add(head, 0x20)
                            }
                            memcpy(add(locationptr, 0x20), mload(add(statePtr, 0x20)), totalBytes)
                            head := add(head, totalBytes)
                            tail := head
                        } default {
                            idx := and(idx, 0x7F)
                            // Get the location of the argument in state, and its length
                            let argptr := getStateSlot(statePtr, idx, 0)
                            let arglen := mload(argptr)
                            // Write a pointer to the argument in the tail part
                            mstore(add(add(inptr, head), 4), tail)
                            head := add(head, 0x20)
                            // Write the argument to the tail part
                            memcpy(add(add(inptr, tail), 4), add(argptr, 0x20), arglen)
                            tail := add(tail, arglen)
                        }
                    }
                    // Word-sized argument
                    default {
                        // Get the location of the argument in state
                        let argptr := getStateSlot(statePtr, idx, 0)
                        // Write the value to the head part
                        mstore(add(add(inptr, head), 4), mload(add(argptr, 0x20)))
                        head := add(head, 0x20)
                    }
                }
                insize := add(tail, 4)
            }


            function wroteNewStateBytesArray(rptr, statePtr) {
                let stateLen := mload(rptr)
                mstore(statePtr, stateLen)
                let dptr := add(statePtr, mul(stateLen, 0x20))
                for { let mp := statePtr let rdp := rptr} gt(stateLen, 0) { stateLen := sub(stateLen, 1) } {
                    mp := add(mp, 0x20)
                    rdp := add(rdp, 0x20)
                    let datalen := mload(add(add(rptr, 0x20),mload(rdp)))
                    memcpy(dptr, add(add(rptr, 0x20),mload(rdp)), add(datalen, 0x20))
                    mstore(mp, dptr)
                    dptr := add(dptr, add(datalen, 0x20))
                }
            }
            
            // Updates the state with return data from the last call
            function writeOutput(index, statePtr) {
                switch and(index, 0x80)
                // Variable length return value
                case 0x80 {
                    if eq(index, 0xFF) {
                        leave
                    }
                    switch and(index, 0xFF)

                    case 0xFE {
                        let argptr := add(statePtr, returndatasize())
                        // Copy the return data to the state variable
                        returndatacopy(argptr, 0, returndatasize())
                        // Check the first word of the return data is a pointer
                        require(eq(mload(argptr), 0x20))
                        wroteNewStateBytesArray(add(argptr, 0x20), statePtr)
                    }
                    default {
                        index := and(index, 0x7F)
                        let argptr := getStateSlot(statePtr, index, sub(returndatasize(), 20))
                        // Copy the return data to the state variable
                        returndatacopy(argptr, 0, returndatasize())
                        // Check the first word of the return data is a pointer
                        require(eq(mload(argptr), 0x20))
                        // Overwrite the first word with the length of the return data
                        mstore(argptr, sub(returndatasize(), 0x20))
                    }
                }
                // Word-sized return value
                default {
                    // Require the return value to be one word long
                    require(eq(returndatasize(), 0x20))
                    let argptr := getStateSlot(statePtr, index, 0x20)
                    // Copy the return data to the state variable
                    mstore(argptr, 0x20)
                    returndatacopy(add(argptr, 0x20), 0, 0x20)
                }
            }

            function doCall(target, statePtr, sel, indices, flags) {
                // Build the command inputs
                let result
                switch and(flags, 0x03)
                case 0x00 { // DELEGATECALL
                    let inptr, insize := buildInputs(statePtr, sel, indices)
                    result := delegatecall(gas(), target, inptr, insize, 0, 0)
                }
                case 0x01 { // CALL
                    let inptr, insize := buildInputs(statePtr, sel, indices)
                    result := call(gas(), target, 0, inptr, insize, 0, 0)
                }
                case 0x02 { // STATICCALL
                    let inptr, insize := buildInputs(statePtr, sel, indices)
                    result := staticcall(gas(), target, inptr, insize, 0, 0)
                }
                case 0x03 { // CALL with value
                    // Get a pointer to the value argument
                    let validx := shr(248, indices)
                    // Check it's not a dynamic argument
                    require(eq(and(validx, 0x80), 0))
                    let valptr := getStateSlot(statePtr, validx, 0)
                    // Check it's 32 bytes long
                    require(eq(mload(valptr), 0x20))
                    // Read the value
                    let val := mload(add(valptr, 0x20))
                    // Remove the value parameter from the indices
                    indices := or(shl(8, indices), 0xff)

                    let inptr, insize := buildInputs(statePtr, sel, indices)
                    result := call(gas(), target, val, inptr, insize, 0, 0)
                }
                require(result)
            }

            function writeTuple(index, statePtr) {
                if eq(index, 0xFF) {
                    leave
                }
                let indexPtr := mload(add(statePtr, mul(0x20, add(index, 1))))

                switch lt(returndatasize(), mload(indexPtr))

                case 1 {
                    mstore(indexPtr, returndatasize())
                    returndatacopy(add(indexPtr, 0x20), 0, returndatasize())
                }
                case 0 {
                    switch eq(returndatasize(),  mload(indexPtr))

                    case 1 {
                        returndatacopy(add(indexPtr, 0x20), 0, returndatasize())
                    }
                    case 0 {
                        let dataSize := returndatasize()
                        // Increase in the length of the data after adding the tuple.
                        let delta := add(sub(dataSize, mload(indexPtr)), 0x20)
                        let stateLen := mload(statePtr)
                        // Move the free pointer
                        let tempPtr := malloc(delta)
                        tempPtr := add(tempPtr, delta)
                        returndatacopy(tempPtr, 0, dataSize)
                        for { let lptrptr := add(statePtr, mul(0x20, stateLen)) } gt(stateLen, 0) { stateLen := sub(stateLen, 1) } {
                            if eq(lptrptr, add(statePtr, mul(0x20, add(index,1)))) {
                                let lptr := mload(lptrptr)
                                mstore(lptr, add(dataSize, 0x20))
                                mstore(add(lptr, 0x20), dataSize)
                                memcpy(add(add(lptr, 0x20), 0x20), tempPtr, dataSize)
                                break
                            }
                            let lptr := mload(lptrptr)
                            let newLocationPtr := add(lptr, delta)
                            memcpy(newLocationPtr, lptr, add(0x20, mload(lptr)))
                            mstore(lptrptr, newLocationPtr)
                            lptrptr := sub(lptrptr, 0x20)
                        }
                        // Move the free pointer to avoid using any garbage data for further command executions
                        pop(malloc(dataSize))
                    }
                }
            }
            
            // Executes a single command against the current state
            function executeCommand(statePtr, command, indices) {
                // Decode the flags
                let flags := and(shr(216, command), 0xff)
                // Decode the function selector
                let sel := and(command, 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000)
                // Make the call
                let target := and(command, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                doCall(target, statePtr, sel, indices, flags)

                // Flag tuple return
                switch and(flags, 0xFF)
                case 0x40 {
                    writeTuple(and(shr(160, command), 0xFF), statePtr)
                } default {
                    // Write the output back to the state
                    writeOutput(and(shr(160, command), 0xFF), statePtr)
                }
            }
            
            // Implements `execute(bytes32[] calldata commands, bytes[] calldata state)`
            function execute() {
                // Load the state into memory
                let statePtr := loadCalldataBytesArray(add(calldataload(0x24), 4))  // 164 th pointer i.e a4

                // Iterate over the commands
                let commandPtr := add(calldataload(0x4), 4)
                for { let commandLen := calldataload(commandPtr) } gt(commandLen, 0) { commandLen := sub(commandLen, 1) } {
                    commandPtr := add(commandPtr, 0x20)
                    // Load the command
                    let command := calldataload(commandPtr)
                    // Unpack the indices from the current command, or the next one if this is an extended command
                    let indices := or(shl(40, command), 0x000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                    if and(command, 0x0000000080000000000000000000000000000000000000000000000000000000) {
                        commandPtr := add(commandPtr, 0x20)
                        commandLen := sub(commandLen, 1)
                        indices := calldataload(commandPtr)
                    }
                    executeCommand(statePtr, command, indices)
                }
            }
        }
    }
}