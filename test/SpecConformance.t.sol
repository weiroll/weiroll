// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "forge-std/Test.sol";
import "src/test/TestableVM.sol";
import "src/Libraries/Math.sol";
import "src/test/MultiReturn.sol";
import "src/Libraries/Tupler.sol";

/// Verifies VM.sol agrees with the README ("Flags" section) and with the
/// official weiroll.js planner (CommandFlags.EXTENDED_COMMAND = 0x40,
/// CommandFlags.TUPLE_RETURN = 0x80).
///
/// README flag byte, MSB first:
///   0   1   2   3   4   5   6   7
/// ┌───┬───┬───────────────┬────────┐
/// │tup│ext│   reserved    │calltype│
/// └───┴───┴───────────────┴────────┘
/// => tup = bit 0 = 0x80, ext = bit 1 = 0x40.
contract SpecConformanceTest is Test {
    event Calculated(uint256 j);

    TestableVM vm_;
    Math math;
    MultiReturn multiReturn;
    LibTupler tupler;

    function setUp() public {
        vm_ = new TestableVM();
        math = new Math();
        multiReturn = new MultiReturn();
        tupler = new LibTupler();
    }

    /// weiroll.js encodes an extended command as two words:
    ///   word N:   selector | flags (ext bit set) | 000000000000 | out | target
    ///   word N+1: 32 one-byte input indices, padded with 0xff
    /// (planner.ts buildCommands: hexConcat([sighash, [flags, 0, 0, 0, 0, 0, 0, ret],
    /// address]) followed by hexConcat([padArray(args, 32, 0xff)]).)
    function test_ExtendedCommandFlag0x40IndicesInNextWord() public {
        bytes32[] memory commands = new bytes32[](2);
        commands[0] = bytes32(
            abi.encodePacked(
                Math.add.selector,
                uint8(0x40), // EXTENDED_COMMAND | DELEGATECALL
                hex"000000000000", // in-field unused for extended commands
                uint8(0x02), // output -> state[2]
                address(math)
            )
        );
        // Input indices: state[0], state[1], rest END_OF_ARGS
        commands[1] = bytes32(
            hex"0001ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(uint256(1));
        state[1] = abi.encode(uint256(2));

        bytes[] memory outState = vm_.execute(commands, state);

        assertEq(
            abi.decode(outState[2], (uint256)),
            3,
            "extended add(1,2) must read indices from the word after the command"
        );
    }

    /// Same plan as Tuple.t.sol, but with the tuple-return flag the official
    /// planner actually emits (0x80, not 0x40).
    function test_TupleReturnFlag0x80RawReturnInState() public {
        bytes32[] memory commands = new bytes32[](3);
        commands[0] = bytes32(
            abi.encodePacked(
                MultiReturn.intTuple.selector,
                hex"80ffffffffffff", // flags = TUPLE_RETURN | DELEGATECALL, no inputs
                bytes1(0x00), // raw return -> state[0]
                address(multiReturn)
            )
        );
        commands[1] = bytes32(
            abi.encodePacked(
                LibTupler.extractElement.selector,
                hex"008001ffffffff", // flags 0x00; dynamic state[0], static state[1]
                bytes1(0x00),
                address(tupler)
            )
        );
        commands[2] = bytes32(
            abi.encodePacked(
                MultiReturn.tupleConsumer.selector,
                hex"0000ffffffffff", // flags 0x00; static state[0]
                bytes1(0xff), // ignore output
                address(multiReturn)
            )
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(uint256(0));
        state[1] = abi.encode(uint256(1)); // extract second element of (0xbad, 0xdeed, 0xcafe)

        vm.expectEmit(true, false, false, true, address(vm_));
        emit Calculated(0xdeed);

        vm_.execute(commands, state);
    }
}
