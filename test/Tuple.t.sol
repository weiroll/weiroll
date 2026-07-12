// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "forge-std/Test.sol";
import "src/test/TestableVM.sol";
import "src/test/MultiReturn.sol";
import "src/Libraries/Tupler.sol";

contract TupleTest is Test {
    event Calculated(uint256 j);

    TestableVM vm_;
    MultiReturn multiReturn;
    LibTupler tupler;

    function setUp() public {
        vm_ = new TestableVM();
        multiReturn = new MultiReturn();
        tupler = new LibTupler();
    }

    // Helper to build command bytes32 manually matching JS test format
    function _encodeCommand(
        address target,
        bytes4 selector,
        bytes memory inargs,
        bytes1 outargs
    ) internal pure returns (bytes32) {
        return bytes32(abi.encodePacked(selector, inargs, outargs, target));
    }

    function test_TupleReturnSliceFirstVar() public {
        // Matches weiroll.js planner encoding (CommandFlags.TUPLE_RETURN = 0x80):
        // [multiReturn, "intTuple",      "0x80ffffffffffff", "0x00"]
        // [tupler,      "extractElement","0x008001ffffffff", "0x00"]
        // [multiReturn, "tupleConsumer", "0x0000ffffffffff", "0xff"]

        bytes32[] memory commands = new bytes32[](3);
        commands[0] = _encodeCommand(
            address(multiReturn),
            MultiReturn.intTuple.selector,
            hex"80ffffffffffff",  // flags=0x80 (TUPLE_RETURN), indices=ffffffffffff
            bytes1(0x00)         // output to state[0]
        );
        commands[1] = _encodeCommand(
            address(tupler),
            LibTupler.extractElement.selector,
            hex"008001ffffffff",  // flags=0x00, indices=8001ffffffff (dynamic state[0], static state[1])
            bytes1(0x00)         // output to state[0]
        );
        commands[2] = _encodeCommand(
            address(multiReturn),
            MultiReturn.tupleConsumer.selector,
            hex"0000ffffffffff",  // flags=0x00, indices=00ffffffffff (static state[0])
            bytes1(0xff)         // no output
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(uint256(0));
        state[1] = abi.encode(uint256(0)); // index 0 -> extract first element

        vm.expectEmit(true, false, false, true, address(vm_));
        emit Calculated(0xbad);

        vm_.execute(commands, state);
    }

    function test_TupleReturnSliceSecondVar() public {
        bytes32[] memory commands = new bytes32[](3);
        commands[0] = _encodeCommand(
            address(multiReturn),
            MultiReturn.intTuple.selector,
            hex"80ffffffffffff",
            bytes1(0x00)
        );
        commands[1] = _encodeCommand(
            address(tupler),
            LibTupler.extractElement.selector,
            hex"008001ffffffff",
            bytes1(0x00)
        );
        commands[2] = _encodeCommand(
            address(multiReturn),
            MultiReturn.tupleConsumer.selector,
            hex"0000ffffffffff",
            bytes1(0xff)
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(uint256(0));
        state[1] = abi.encode(uint256(1)); // index 1 -> extract second element

        vm.expectEmit(true, false, false, true, address(vm_));
        emit Calculated(0xdeed);

        vm_.execute(commands, state);
    }
}
