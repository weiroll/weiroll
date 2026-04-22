// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "forge-std/Test.sol";
import "src/test/CommandBuilderHarness.sol";
import "src/Libraries/Math.sol";
import "src/Libraries/Strings.sol";

contract CommandBuilderFuzzTest is Test {
    CommandBuilderHarness cbh;

    function setUp() public {
        cbh = new CommandBuilderHarness();
    }

    function _endMarkers2(bytes1 first, bytes1 second) internal pure returns (bytes32) {
        return bytes32(
            (uint256(uint8(first)) << 248) |
            (uint256(uint8(second)) << 240) |
            (type(uint256).max >> 16)
        );
    }

    function _endMarkers1(bytes1 first) internal pure returns (bytes32) {
        return bytes32(
            (uint256(uint8(first)) << 248) |
            (type(uint256).max >> 8)
        );
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
        return abi.encodePacked(uint256(data.length), _padTo32(data));
    }

    // buildInputs fuzz

    function testFuzz_BuildInputs_StaticArgs(uint256 a, uint256 b) public {
        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(a);
        state[1] = abi.encode(b);

        bytes32 indices = _endMarkers2(bytes1(0x00), bytes1(0x01));
        bytes4 selector = Math.add.selector;

        bytes memory result = cbh.testBuildInputs(state, selector, indices);
        bytes memory expected = abi.encodeWithSelector(selector, a, b);
        assertEq(result, expected);
    }

    function testFuzz_BuildInputs_DynamicBytes(bytes memory data) public {
        vm.assume(data.length <= 1024);

        bytes[] memory state = new bytes[](1);
        state[0] = _encodeDynamic(data);

        bytes32 indices = _endMarkers1(bytes1(0x80));
        bytes4 selector = Strings.strlen.selector;

        bytes memory result = cbh.testBuildInputs(state, selector, indices);
        bytes memory expected = abi.encodeWithSelector(selector, string(data));
        assertEq(result, expected);
    }

    function testFuzz_BuildInputs_UseState(uint8 slotCount) public {
        uint256 count = bound(slotCount, 1, 8);
        bytes[] memory state = new bytes[](count);
        for (uint256 i = 0; i < count; i++) {
            state[i] = abi.encode(uint256(i * 100 + 7));
        }

        bytes32 indices = _endMarkers1(bytes1(0xfe));
        bytes memory result = cbh.testBuildInputs(state, bytes4(0x12345678), indices);

        // Strip selector, decode the bytes[] tail.
        bytes memory tail = new bytes(result.length - 4);
        for (uint256 i = 4; i < result.length; i++) {
            tail[i - 4] = result[i];
        }
        bytes[] memory decoded = abi.decode(tail, (bytes[]));
        assertEq(decoded.length, count);
        for (uint256 i = 0; i < count; i++) {
            assertEq(decoded[i], state[i]);
        }
    }

    function testFuzz_BuildInputs_RejectsUnalignedDynamic(bytes memory data) public {
        vm.assume(data.length > 0 && data.length % 32 != 0);

        bytes[] memory state = new bytes[](1);
        state[0] = data;

        bytes32 indices = _endMarkers1(bytes1(0x80));
        vm.expectRevert(bytes("Dynamic state variables must be a multiple of 32 bytes"));
        cbh.testBuildInputs(state, bytes4(0x12345678), indices);
    }

    function testFuzz_BuildInputs_RejectsNonWordStatic(uint8 len) public {
        uint256 bounded = bound(len, 0, 128);
        vm.assume(bounded != 32);

        bytes[] memory state = new bytes[](1);
        state[0] = new bytes(bounded);

        bytes32 indices = _endMarkers1(bytes1(0x00));
        vm.expectRevert(bytes("Static state variables must be 32 bytes"));
        cbh.testBuildInputs(state, bytes4(0x12345678), indices);
    }

    // writeOutputs fuzz

    function testFuzz_WriteOutputs_StaticRoundtrip(bytes32 word, uint8 slot) public {
        uint256 s = bound(slot, 0, 125);
        bytes[] memory state = new bytes[](s + 2);
        for (uint256 i = 0; i < state.length; i++) {
            state[i] = abi.encode(uint256(i + 1));
        }
        bytes memory neighbour = state[s + 1];

        bytes memory output = abi.encode(word);
        (bytes[] memory newState,) = cbh.testWriteOutputs(state, bytes1(uint8(s)), output);

        assertEq(newState[s], output);
        assertEq(newState[s + 1], neighbour);
    }

    function testFuzz_WriteOutputs_DynamicRoundtrip(bytes memory payload, uint8 slot) public {
        vm.assume(payload.length <= 512);
        uint256 s = bound(slot, 0, 125);

        bytes[] memory state = new bytes[](s + 1);
        for (uint256 i = 0; i < state.length; i++) {
            state[i] = abi.encode(uint256(i + 1));
        }

        bytes memory output = abi.encode(payload);
        bytes1 index = bytes1(uint8(s) | 0x80);
        (bytes[] memory newState,) = cbh.testWriteOutputs(state, index, output);

        // After writeOutputs, state[s] holds [payload.length word][padded payload].
        // That format matches the dynamic state layout buildInputs expects.
        bytes memory expected = abi.encodePacked(uint256(payload.length), _padTo32(payload));
        assertEq(newState[s], expected);
    }

    function testFuzz_WriteOutputs_UseStateDecode(uint8 len) public {
        uint256 count = bound(len, 0, 6);
        bytes[] memory payload = new bytes[](count);
        for (uint256 i = 0; i < count; i++) {
            payload[i] = abi.encodePacked(bytes32(uint256(i + 1)));
        }

        bytes[] memory initial = new bytes[](3);
        initial[0] = abi.encode(uint256(99));
        initial[1] = abi.encode(uint256(88));
        initial[2] = abi.encode(uint256(77));

        bytes memory output = abi.encode(payload);
        (bytes[] memory newState,) = cbh.testWriteOutputs(initial, bytes1(0xfe), output);

        assertEq(newState.length, count);
        for (uint256 i = 0; i < count; i++) {
            assertEq(newState[i], payload[i]);
        }
    }

    function testFuzz_WriteOutputs_RejectsMultiReturnStatic(bytes memory output) public {
        vm.assume(output.length != 32);

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(uint256(0));
        state[1] = abi.encode(uint256(0));

        vm.expectRevert(bytes("Only one return value permitted (static)"));
        cbh.testWriteOutputs(state, bytes1(0x00), output);
    }

    function testFuzz_WriteOutputs_EndSentinelNoop(bytes memory output) public {
        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(uint256(1));
        state[1] = abi.encode(uint256(2));
        state[2] = abi.encode(uint256(3));

        (bytes[] memory newState,) = cbh.testWriteOutputs(state, bytes1(0xff), output);
        assertEq(newState.length, 3);
        assertEq(newState[0], state[0]);
        assertEq(newState[1], state[1]);
        assertEq(newState[2], state[2]);
    }
}
