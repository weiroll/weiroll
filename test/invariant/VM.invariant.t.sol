// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "forge-std/Test.sol";
import "src/test/TestableVM.sol";
import "src/Libraries/Math.sol";
import "src/Libraries/Strings.sol";
import "./VMHandler.sol";

contract VMInvariantTest is Test {
    TestableVM internal vm_;
    Math internal math;
    Strings internal strings;
    VMInvariantHandler internal handler;

    bytes32 internal initialVmCodehash;

    function setUp() public {
        vm_ = new TestableVM();
        math = new Math();
        strings = new Strings();
        handler = new VMInvariantHandler(vm_, math, strings);

        initialVmCodehash = address(vm_).codehash;

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = VMInvariantHandler.executeMathAdd.selector;
        selectors[1] = VMInvariantHandler.executeStrcat.selector;
        selectors[2] = VMInvariantHandler.executeEmptyCommands.selector;
        selectors[3] = VMInvariantHandler.executeJunkFlags.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_vmCodeStable() public {
        assertEq(address(vm_).codehash, initialVmCodehash);
    }

    function invariant_emptyCommandsPreserveState() public {
        assertEq(handler.emptyCallsCorruptedState(), 0);
    }

    function invariant_successfulCallsPreserveStateShape() public {
        assertEq(handler.corruptedStateAfterSuccess(), 0);
    }

    function invariant_callCountersConsistent() public {
        uint256 total = handler.totalCalls();
        uint256 branches = handler.successfulAdds()
            + handler.successfulStrcats()
            + handler.emptyCalls()
            + handler.junkFlagSuccesses()
            + handler.junkFlagReverts();
        // Every recorded branch is an observation of totalCalls, but not every call records.
        // Failed adds/strcats are silent, so branches <= total. The counters should never exceed total.
        assertLe(branches, total + handler.emptyCallsCorruptedState());
    }
}
