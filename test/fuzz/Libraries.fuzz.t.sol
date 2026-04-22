// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "forge-std/Test.sol";
import "src/Libraries/Math.sol";
import "src/Libraries/Strings.sol";
import "src/Libraries/Tupler.sol";

contract LibrariesFuzzTest is Test {
    Math math;
    Strings strings;
    LibTupler tupler;

    function setUp() public {
        math = new Math();
        strings = new Strings();
        tupler = new LibTupler();
    }

    // Math

    function testFuzz_MathAddSub(uint256 a, uint256 b) public {
        b = bound(b, 0, a);
        assertEq(math.add(math.sub(a, b), b), a);
    }

    function testFuzz_MathMulCommutative(uint128 a, uint128 b) public {
        assertEq(math.mul(a, b), math.mul(b, a));
    }

    function testFuzz_MathSumMatchesLoop(uint256[] memory xs) public {
        vm.assume(xs.length <= 32);
        uint256 cap = type(uint256).max / 32;
        for (uint256 i = 0; i < xs.length; i++) {
            xs[i] = bound(xs[i], 0, cap);
        }

        uint256 expected;
        unchecked {
            for (uint256 i = 0; i < xs.length; i++) {
                expected += xs[i];
            }
        }
        assertEq(math.sum(xs), expected);
    }

    // Strings

    function testFuzz_StringsStrlen(string memory s) public {
        assertEq(strings.strlen(s), bytes(s).length);
    }

    function testFuzz_StringsStrcatLength(string memory a, string memory b) public {
        string memory cat = strings.strcat(a, b);
        assertEq(bytes(cat).length, bytes(a).length + bytes(b).length);
    }

    function testFuzz_StringsStrcatContent(string memory a, string memory b) public {
        vm.assume(bytes(a).length + bytes(b).length <= 2048);
        bytes memory cat = bytes(strings.strcat(a, b));
        bytes memory ab = bytes(a);
        bytes memory bb = bytes(b);
        for (uint256 i = 0; i < ab.length; i++) {
            assertEq(cat[i], ab[i]);
        }
        for (uint256 i = 0; i < bb.length; i++) {
            assertEq(cat[ab.length + i], bb[i]);
        }
    }

    // Tupler

    function testFuzz_TuplerExtract(bytes32[] memory words, uint256 idx) public {
        vm.assume(words.length > 0 && words.length <= 16);
        idx = bound(idx, 0, words.length - 1);

        // Tupler reads a raw concatenated tuple (no length prefix in data).
        bytes memory tuple;
        for (uint256 i = 0; i < words.length; i++) {
            tuple = bytes.concat(tuple, abi.encodePacked(words[i]));
        }

        bytes32 got = tupler.extractElement(tuple, idx);
        assertEq(got, words[idx]);
    }
}
