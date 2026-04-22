// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "forge-std/Test.sol";
import "src/test/TestableVM.sol";
import "src/Libraries/Math.sol";
import "src/Libraries/Strings.sol";
import "src/test/Revert.sol";
import "src/VM.sol";

contract VMFuzzTest is Test {
    TestableVM vm_;
    Math math;
    Strings strings;
    Revert reverter;

    function setUp() public {
        vm_ = new TestableVM();
        math = new Math();
        strings = new Strings();
        reverter = new Revert();
    }

    function _buildCommand(
        bytes4 selector,
        uint8 flags,
        bytes memory inputIndices,
        uint8 outputIndex,
        address target
    ) internal pure returns (bytes32) {
        bytes memory indices = new bytes(6);
        for (uint256 i = 0; i < 6; i++) {
            indices[i] = i < inputIndices.length ? inputIndices[i] : bytes1(0xff);
        }
        return bytes32(abi.encodePacked(selector, flags, indices, outputIndex, target));
    }

    function _padTo32(bytes memory data) internal pure returns (bytes memory) {
        uint256 padded = ((data.length + 31) / 32) * 32;
        bytes memory out = new bytes(padded);
        for (uint256 i = 0; i < data.length; i++) {
            out[i] = data[i];
        }
        return out;
    }

    function _encodeDynamic(bytes memory data) internal pure returns (bytes memory) {
        uint256 paddedLen = ((data.length + 31) / 32) * 32;
        bytes memory result = new bytes(32 + paddedLen);
        assembly {
            mstore(add(result, 32), mload(data))
        }
        for (uint256 i = 0; i < data.length; i++) {
            result[32 + i] = data[i];
        }
        return result;
    }

    function testFuzz_VM_MathAdd(uint256 a, uint256 b) public {
        a = bound(a, 0, type(uint128).max);
        b = bound(b, 0, type(uint128).max);

        bytes32[] memory commands = new bytes32[](1);
        commands[0] = _buildCommand(
            Math.add.selector,
            0x00,
            abi.encodePacked(uint8(0x00), uint8(0x01)),
            0x02,
            address(math)
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(a);
        state[1] = abi.encode(b);
        state[2] = abi.encode(uint256(0));

        bytes[] memory result = vm_.execute(commands, state);
        assertEq(abi.decode(result[2], (uint256)), a + b);
    }

    function testFuzz_VM_MathSub(uint256 a, uint256 b) public {
        b = bound(b, 0, a);

        bytes32[] memory commands = new bytes32[](1);
        commands[0] = _buildCommand(
            Math.sub.selector,
            0x00,
            abi.encodePacked(uint8(0x00), uint8(0x01)),
            0x02,
            address(math)
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(a);
        state[1] = abi.encode(b);
        state[2] = abi.encode(uint256(0));

        bytes[] memory result = vm_.execute(commands, state);
        assertEq(abi.decode(result[2], (uint256)), a - b);
    }

    function testFuzz_VM_Strlen(bytes memory data) public {
        vm.assume(data.length <= 2048);

        bytes32[] memory commands = new bytes32[](1);
        commands[0] = _buildCommand(
            Strings.strlen.selector,
            0x00,
            abi.encodePacked(uint8(0x80)),
            0x01,
            address(strings)
        );

        bytes[] memory state = new bytes[](2);
        state[0] = _encodeDynamic(data);
        state[1] = abi.encode(uint256(0));

        bytes[] memory result = vm_.execute(commands, state);
        assertEq(abi.decode(result[1], (uint256)), data.length);
    }

    function testFuzz_VM_Strcat(bytes memory a, bytes memory b) public {
        vm.assume(a.length + b.length <= 1024);

        bytes32[] memory commands = new bytes32[](1);
        commands[0] = _buildCommand(
            Strings.strcat.selector,
            0x00,
            abi.encodePacked(uint8(0x80), uint8(0x81)),
            0x82,
            address(strings)
        );

        bytes[] memory state = new bytes[](3);
        state[0] = _encodeDynamic(a);
        state[1] = _encodeDynamic(b);
        state[2] = _encodeDynamic(bytes(""));

        bytes[] memory result = vm_.execute(commands, state);

        bytes memory concat = bytes.concat(a, b);
        bytes memory expected = abi.encodePacked(uint256(concat.length), _padTo32(concat));
        assertEq(result[2], expected);
    }

    function testFuzz_VM_RejectsValueCallWithoutValueSlot(uint8 rawLen) public {
        uint256 len = bound(rawLen, 0, 96);
        vm.assume(len != 32);

        bytes32[] memory commands = new bytes32[](1);
        commands[0] = _buildCommand(
            Math.add.selector,
            0x03,
            abi.encodePacked(uint8(0x00), uint8(0x01), uint8(0x02)),
            0xff,
            address(math)
        );

        bytes[] memory state = new bytes[](3);
        state[0] = new bytes(len);
        state[1] = abi.encode(uint256(1));
        state[2] = abi.encode(uint256(2));

        vm.expectRevert(bytes("_execute: value call has no value indicated."));
        vm_.execute(commands, state);
    }

    function testFuzz_VM_BubblesTargetRevert(uint256 salt) public {
        salt; // silence unused warning; the fuzzer varies the input but the target always reverts

        bytes32[] memory commands = new bytes32[](1);
        commands[0] = _buildCommand(
            Revert.fail.selector,
            0x00,
            new bytes(0),
            0xff,
            address(reverter)
        );

        bytes[] memory state = new bytes[](0);

        vm.expectRevert(
            abi.encodeWithSelector(
                VM.ExecutionFailed.selector,
                uint256(0),
                address(reverter),
                "Hello World!"
            )
        );
        vm_.execute(commands, state);
    }

    function testFuzz_VM_EmptyCommandsPreservesState(uint256 a, uint256 b, bytes memory c) public {
        vm.assume(c.length <= 1024);

        bytes32[] memory commands = new bytes32[](0);
        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(a);
        state[1] = abi.encode(b);
        state[2] = _encodeDynamic(c);

        bytes[] memory result = vm_.execute(commands, state);
        assertEq(result.length, 3);
        assertEq(result[0], state[0]);
        assertEq(result[1], state[1]);
        assertEq(result[2], state[2]);
    }
}
