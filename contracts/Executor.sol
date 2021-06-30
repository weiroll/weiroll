object "Executor" {
    code {
        datacopy(0, dataoffset("runtime"), datasize("runtime"))
        return(0, datasize("runtime"))
    }
    object "runtime" {
        code {
            mstore(0x20, 0x40)

            switch selector()
            case 0xde792d5f { // execute(bytes32[], bytes[])
                execute()
            }
            default {
                revert(0, 0)
            }
            
            function selector() -> s {
                s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
            }

            function require(condition) {
                if iszero(condition) { revert(0, 0) }
            }
            
            function malloc(amt) -> ptr {
                amt := mul(div(add(amt, 0x1F), 0x20), 0x20) // Round up to word boundary
                ptr := mload(0x20)
                mstore(0x20, add(ptr, amt))
            }
            
            function memcpy(d, s, l) {
                pop(staticcall(gas(), 4, s, l, d, l))
            }
            
            function loadCalldataBytes(cdp) -> mp {
                let dataLen := calldataload(cdp)
                mp := malloc(add(dataLen, 0x20))
                calldatacopy(mp, cdp, add(dataLen, 0x20))
            }
            
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
            
            function getInputLength(statePtr, indices) -> headlen {
                headlen := 0
                for { let i := 0 } lt(i, 32) { i := add(i, 1) } {
                    let idx := and(shr(sub(248, mul(i, 8)), indices), 0xFF)
                    if eq(idx, 0xFF) {
                        break
                    }
                    headlen := add(headlen, 32)
                }
            }
            
            function buildInputs(statePtr, sel, indices) -> inptr, insize {
                let headlen := getInputLength(statePtr, indices)
                inptr := mload(0x20)
                mstore(inptr, sel)
                
                let head := 0
                let tail := headlen
                for { let i := 0 } lt(i, 32) { i := add(i, 1) } {
                    let idx := and(shr(sub(248, mul(i, 8)), indices), 0xFF)
                    if eq(idx, 0xFF) {
                        break
                    }
                    switch and(idx, 0x80)
                    case 0x80 {
                        idx := and(idx, 0x7F)
                        let argptr := mload(add(statePtr, mul(add(idx, 1), 0x20)))
                        let arglen := mload(argptr)
                        mstore(add(add(inptr, head), 4), tail)
                        head := add(head, 0x20)
                        memcpy(add(add(inptr, tail), 4), add(argptr, 0x20), arglen)
                        tail := add(tail, arglen)
                    }
                    default {
                        let argptr := mload(add(statePtr, mul(add(idx, 1), 0x20)))
                        mstore(add(add(inptr, head), 4), mload(add(argptr, 0x20)))
                        head := add(head, 0x20)
                    }
                }
                insize := add(tail, 4)
            }
            
            function writeOutput(index, statePtr) {
                if eq(index, 0xFF) {
                    leave
                }
                switch and(index, 0x80)
                case 0x80 {
                    index := and(index, 0x7F)
                    let argptrptr := add(statePtr, mul(add(index, 1), 0x20))
                    let argptr := mload(argptrptr)
                    if lt(mload(argptr), sub(returndatasize(), 0x20)) {
                        argptr := malloc(returndatasize())
                        mstore(argptrptr, argptr)
                    }
                    returndatacopy(argptr, 0, returndatasize())
                    require(eq(mload(argptr), 0x20))
                    mstore(argptr, sub(returndatasize(), 0x20))
                }
                default {
                    require(eq(returndatasize(), 0x20))
                    let argptrptr := add(statePtr, mul(add(index, 1), 0x20))
                    let argptr := mload(argptrptr)
                    if lt(mload(argptr), 0x20) {
                        argptr := malloc(0x40)
                        mstore(argptrptr, argptr)
                    }
                    mstore(argptr, 0x20)
                    returndatacopy(add(argptr, 0x20), 0, 0x20)
                }
            }
            
            function executeCommand(statePtr, command, indices) {
                let flags := and(shr(216, command), 0xff)
                let sel := and(command, 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000)
                let inptr, insize := buildInputs(statePtr, sel, indices)
                let result := delegatecall(gas(), and(command, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF), inptr, insize, 0, 0)
                require(result)
                writeOutput(and(shr(160, command), 0xFF), statePtr)
            }
            
            function execute() {
                let statePtr := loadCalldataBytesArray(add(calldataload(0x24), 4))
                let commandPtr := add(calldataload(0x4), 4)
                for { let commandLen := calldataload(commandPtr) } gt(commandLen, 0) { commandLen := sub(commandLen, 1) } {
                    commandPtr := add(commandPtr, 0x20)
                    let command := calldataload(commandPtr)
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