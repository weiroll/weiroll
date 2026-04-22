// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "forge-std/Test.sol";
import "src/test/TestableVM.sol";
import "src/Libraries/Math.sol";
import "src/Libraries/Strings.sol";

contract VMInvariantHandler is Test {
    TestableVM public immutable vm_;
    Math public immutable math;
    Strings public immutable strings;

    uint256 public totalCalls;
    uint256 public successfulAdds;
    uint256 public successfulStrcats;
    uint256 public emptyCalls;
    uint256 public emptyCallsCorruptedState;
    uint256 public junkFlagSuccesses;
    uint256 public junkFlagReverts;
    uint256 public corruptedStateAfterSuccess;

    bytes[] internal lastState;

    constructor(TestableVM _vm, Math _math, Strings _strings) {
        vm_ = _vm;
        math = _math;
        strings = _strings;
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

    function executeMathAdd(uint256 a, uint256 b) external {
        totalCalls++;
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

        try vm_.execute(commands, state) returns (bytes[] memory result) {
            successfulAdds++;
            if (result.length != 3) {
                corruptedStateAfterSuccess++;
            } else if (abi.decode(result[2], (uint256)) != a + b) {
                corruptedStateAfterSuccess++;
            }
            lastState = result;
        } catch {}
    }

    function executeStrcat(bytes memory a, bytes memory b) external {
        totalCalls++;
        if (a.length + b.length > 1024) return;

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

        try vm_.execute(commands, state) returns (bytes[] memory result) {
            successfulStrcats++;
            if (result.length != 3) {
                corruptedStateAfterSuccess++;
            }
            lastState = result;
        } catch {}
    }

    function executeEmptyCommands(uint256 a, uint256 b) external {
        totalCalls++;
        emptyCalls++;

        bytes32[] memory commands = new bytes32[](0);
        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(a);
        state[1] = abi.encode(b);

        bytes[] memory result = vm_.execute(commands, state);
        if (result.length != 2) {
            emptyCallsCorruptedState++;
            return;
        }
        if (keccak256(result[0]) != keccak256(state[0]) || keccak256(result[1]) != keccak256(state[1])) {
            emptyCallsCorruptedState++;
        }
    }

    function executeJunkFlags(uint8 rawFlags, uint256 a, uint256 b) external {
        totalCalls++;
        a = bound(a, 0, type(uint128).max);
        b = bound(b, 0, type(uint128).max);

        // Force a valid call-type in the low bits, but let the fuzzer wiggle FLAG_EXTENDED_COMMAND and FLAG_TUPLE_RETURN.
        uint8 flags = (rawFlags & 0xFC) | (rawFlags & 0x03);

        bytes32[] memory commands = new bytes32[](1);
        commands[0] = _buildCommand(
            Math.add.selector,
            flags,
            abi.encodePacked(uint8(0x00), uint8(0x01)),
            0x02,
            address(math)
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(a);
        state[1] = abi.encode(b);
        state[2] = abi.encode(uint256(0));

        try vm_.execute(commands, state) returns (bytes[] memory result) {
            junkFlagSuccesses++;
            // Roundtrip: re-encoding the state must succeed, else flags corrupted the output.
            bytes memory roundtrip = abi.encode(result);
            bytes[] memory decoded = abi.decode(roundtrip, (bytes[]));
            if (decoded.length != result.length) {
                corruptedStateAfterSuccess++;
            }
        } catch {
            junkFlagReverts++;
        }
    }
}
