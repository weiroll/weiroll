// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "forge-std/Test.sol";
import "src/test/CommandBuilderHarness.sol";
import "src/Libraries/Math.sol";
import "src/Libraries/Strings.sol";

contract CommandBuilderTest is Test {
    CommandBuilderHarness cbh;
    Math math;
    Strings strings;

    function setUp() public {
        cbh = new CommandBuilderHarness();
        math = new Math();
        strings = new Strings();
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

    function test_BuildInputs_MathAdd() public {
        // Math.add(1, 2) - two uint256 static args
        bytes4 selector = Math.add.selector;

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(uint256(1));
        state[1] = abi.encode(uint256(2));

        // indices: state[0], state[1], then 0xff padding
        bytes32 indices = bytes32(
            abi.encodePacked(
                uint8(0x00), uint8(0x01),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff)
            )
        );

        bytes memory result = cbh.testBuildInputs(state, selector, indices);
        bytes memory expected = abi.encodeWithSelector(selector, uint256(1), uint256(2));
        assertEq(result, expected);
    }

    function test_BuildInputs_Strcat() public {
        bytes4 selector = Strings.strcat.selector;

        bytes[] memory state = new bytes[](2);
        state[0] = _encodeDynamic(bytes("Hello"));
        state[1] = _encodeDynamic(bytes(" World!"));

        // indices: 0x80 (dynamic state[0]), 0x81 (dynamic state[1])
        bytes32 indices = bytes32(
            abi.encodePacked(
                uint8(0x80), uint8(0x81),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff)
            )
        );

        bytes memory result = cbh.testBuildInputs(state, selector, indices);
        bytes memory expected = abi.encodeWithSelector(selector, "Hello", " World!");
        assertEq(result, expected);
    }

    function test_BuildInputs_MathSum() public {
        bytes4 selector = Math.sum.selector;

        uint256[] memory arr = new uint256[](3);
        arr[0] = 0xAAA0000000000000000000000000000000000000000000000000000000000002;
        arr[1] = 0x1111111111111111111111111111111111111111111111111111111111111111;
        arr[2] = 0x2222222222222222222222222222222222222222222222222222222222222222;

        bytes[] memory state = new bytes[](1);
        // Dynamic state: length + elements (no offset pointer)
        state[0] = abi.encodePacked(uint256(3), arr[0], arr[1], arr[2]);

        bytes32 indices = bytes32(
            abi.encodePacked(
                uint8(0x80),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff)
            )
        );

        bytes memory result = cbh.testBuildInputs(state, selector, indices);
        bytes memory expected = abi.encodeWithSelector(selector, arr);
        assertEq(result, expected);
    }

    function test_WriteOutputs_Static() public {
        bytes[] memory state = new bytes[](3);
        state[0] = hex"000000000000000000000000000000000000000000000000000000000000000a";
        state[1] = hex"1111111111111111111111111111111111111111111111111111111111111111";
        state[2] = hex"2222222222222222222222222222222222222222222222222222222222222222";

        bytes1 index = bytes1(0x00);
        bytes memory output = hex"0000000000000000000000000000000000000000000000000000000000000000";

        (bytes[] memory newState, bytes memory retOutput) = cbh.testWriteOutputs(state, index, output);

        assertEq(newState[0], output);
        assertEq(newState[1], state[1]);
        assertEq(newState[2], state[2]);
    }

    function test_WriteOutputs_Dynamic() public {
        bytes[] memory state = new bytes[](3);
        state[0] = hex"000000000000000000000000000000000000000000000000000000000000000a";
        state[1] = hex"1111111111111111111111111111111111111111111111111111111111111111";
        state[2] = hex"2222222222222222222222222222222222222222222222222222222222222222";

        bytes1 index = bytes1(0x81); // dynamic, slot 1

        uint256[] memory arr = new uint256[](3);
        arr[0] = 1;
        arr[1] = 2;
        arr[2] = 3;
        bytes memory output = abi.encode(arr);

        (bytes[] memory newState,) = cbh.testWriteOutputs(state, index, output);

        // The dynamic output should be stored in state[1] as the raw data (without offset pointer)
        // i.e., output starting from byte 32 (skipping the offset pointer 0x20)
        bytes memory expectedSlot1 = new bytes(output.length - 32);
        for (uint256 i = 32; i < output.length; i++) {
            expectedSlot1[i - 32] = output[i];
        }
        assertEq(newState[1], expectedSlot1);
    }

    function test_WriteOutputs_RawCall() public {
        bytes[] memory state = new bytes[](3);
        state[0] = hex"000000000000000000000000000000000000000000000000000000000000000a";
        state[1] = hex"1111111111111111111111111111111111111111111111111111111111111111";
        state[2] = hex"2222222222222222222222222222222222222222222222222222222222222222";

        bytes1 index = bytes1(0xfe); // IDX_USE_STATE

        bytes[] memory precoded = new bytes[](3);
        precoded[0] = hex"11";
        precoded[1] = hex"22";
        precoded[2] = hex"33";

        bytes memory output = abi.encode(precoded);

        (bytes[] memory newState, bytes memory retOutput) = cbh.testWriteOutputs(state, index, output);

        // When index is IDX_USE_STATE (0xfe), the entire state is replaced with decoded output
        assertEq(newState.length, 3);
        assertEq(newState[0], precoded[0]);
        assertEq(newState[1], precoded[1]);
        assertEq(newState[2], precoded[2]);
    }
}
