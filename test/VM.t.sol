// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "forge-std/Test.sol";
import "src/test/TestableVM.sol";
import "src/Libraries/Events.sol";
import "src/Libraries/Math.sol";
import "src/Libraries/Strings.sol";
import "src/test/Sender.sol";
import "src/test/Revert.sol";
import "src/test/Payable.sol";
import "src/test/StateTest.sol";
import "src/test/SimpleToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VMTest is Test {
    event LogAddress(address message);
    event LogUint(uint256 message);
    event LogString(string message);
    event Transfer(address indexed from, address indexed to, uint256 value);

    TestableVM vm_;
    Events events;
    Math math;
    Strings strings;
    Sender sender_;
    Revert reverter;
    Payable payable_;
    StateTest stateTest;
    ExecutorToken token;

    uint256 supply = 100000000000000000000;

    function setUp() public {
        vm_ = new TestableVM();
        events = new Events();
        math = new Math();
        strings = new Strings();
        sender_ = new Sender();
        reverter = new Revert();
        payable_ = new Payable();
        stateTest = new StateTest();
        token = new ExecutorToken(supply);
    }

    // Helper: build a command bytes32
    // Layout: [selector(4)][flags(1)][inputIndices(6)][outputIndex(1)][target(20)]
    function _buildCommand(
        bytes4 selector,
        uint8 flags,
        bytes memory inputIndices,
        uint8 outputIndex,
        address target
    ) internal pure returns (bytes32) {
        // Pad inputIndices to 6 bytes with 0xff
        bytes memory indices = new bytes(6);
        for (uint256 i = 0; i < 6; i++) {
            if (i < inputIndices.length) {
                indices[i] = inputIndices[i];
            } else {
                indices[i] = bytes1(0xff);
            }
        }

        return bytes32(
            abi.encodePacked(selector, flags, indices, outputIndex, target)
        );
    }

    // Encode a dynamic value for state: length-prefixed, padded to 32-byte boundary
    function _encodeDynamic(bytes memory data) internal pure returns (bytes memory) {
        uint256 paddedLen = ((data.length + 31) / 32) * 32;
        bytes memory result = new bytes(32 + paddedLen);
        assembly {
            mstore(add(result, 32), mload(data)) // store length
        }
        for (uint256 i = 0; i < data.length; i++) {
            result[32 + i] = data[i];
        }
        return result;
    }

    function test_MsgSender() public {
        // Command 1: delegatecall Sender.sender() -> state[0]
        bytes32 cmd1 = _buildCommand(
            Sender.sender.selector,
            0x00, // delegatecall
            new bytes(0), // no inputs
            0x00, // output to state[0]
            address(sender_)
        );

        // Command 2: delegatecall Events.logAddress(state[0])
        bytes32 cmd2 = _buildCommand(
            Events.logAddress.selector,
            0x00, // delegatecall
            abi.encodePacked(uint8(0x00)), // input from state[0]
            0xff, // no output
            address(events)
        );

        bytes32[] memory commands = new bytes32[](2);
        commands[0] = cmd1;
        commands[1] = cmd2;

        bytes[] memory state = new bytes[](1);
        state[0] = abi.encode(uint256(0));

        vm.expectEmit(true, false, false, true, address(vm_));
        emit LogAddress(address(this));

        vm_.execute(commands, state);
    }

    function test_SimpleAddition() public {
        // Fibonacci: start with a=1, b=1, do 8 additions to get 55
        // We need state slots for intermediates
        // state[0] = 1 (a), state[1] = 1 (b)
        // After 8 iterations: result = 55

        // Each Math.add(a, b) takes two state slots as input, outputs to a state slot
        // The planner resolves this as a chain of additions

        // Let's manually trace the fibonacci:
        // iter 0: add(1,1)=2, a=1, b=2
        // iter 1: add(1,2)=3, a=2, b=3
        // iter 2: add(2,3)=5, a=3, b=5
        // iter 3: add(3,5)=8, a=5, b=8
        // iter 4: add(5,8)=13, a=8, b=13
        // iter 5: add(8,13)=21, a=13, b=21
        // iter 6: add(13,21)=34, a=21, b=34
        // iter 7: add(21,34)=55, a=34, b=55
        // final b = 55

        // State layout: slots 0..9 for values
        // state[0] = 1 (literal a)
        // state[1] = 1 (literal b)
        // state[2] = add(0,1) = 2
        // state[3] = add(1,2) = 3
        // state[4] = add(2,3) = 5
        // state[5] = add(3,4) = 8
        // state[6] = add(4,5) = 13
        // state[7] = add(5,6) = 21
        // state[8] = add(6,7) = 34
        // state[9] = add(7,8) = 55

        bytes32[] memory commands = new bytes32[](9); // 8 adds + 1 log
        // 8 add commands
        for (uint8 i = 0; i < 8; i++) {
            commands[i] = _buildCommand(
                Math.add.selector,
                0x00, // delegatecall
                abi.encodePacked(uint8(i), uint8(i + 1)),
                uint8(i + 2), // output to next slot
                address(math)
            );
        }
        // Log the final result
        commands[8] = _buildCommand(
            Events.logUint.selector,
            0x00, // delegatecall
            abi.encodePacked(uint8(9)), // state[9] = 55
            0xff,
            address(events)
        );

        bytes[] memory state = new bytes[](10);
        state[0] = abi.encode(uint256(1));
        state[1] = abi.encode(uint256(1));
        for (uint256 i = 2; i < 10; i++) {
            state[i] = abi.encode(uint256(0));
        }

        vm.expectEmit(true, false, false, true, address(vm_));
        emit LogUint(55);

        vm_.execute(commands, state);
    }

    function test_StringLength() public {
        // delegatecall Strings.strlen("Hello, world!") -> state[0]
        // delegatecall Events.logUint(state[0])
        // "Hello, world!" is 13 chars

        bytes32[] memory commands = new bytes32[](2);
        commands[0] = _buildCommand(
            Strings.strlen.selector,
            0x00,
            abi.encodePacked(uint8(0x80)), // dynamic input from state[0]
            0x01, // output to state[1]
            address(strings)
        );
        commands[1] = _buildCommand(
            Events.logUint.selector,
            0x00,
            abi.encodePacked(uint8(0x01)),
            0xff,
            address(events)
        );

        bytes[] memory state = new bytes[](2);
        state[0] = _encodeDynamic(bytes("Hello, world!"));
        state[1] = abi.encode(uint256(0));

        vm.expectEmit(true, false, false, true, address(vm_));
        emit LogUint(13);

        vm_.execute(commands, state);
    }

    function test_ConcatenateTwoStrings() public {
        // delegatecall Strings.strcat(state[0], state[1]) -> state[2]
        // delegatecall Events.logString(state[2])

        bytes32[] memory commands = new bytes32[](2);
        commands[0] = _buildCommand(
            Strings.strcat.selector,
            0x00,
            abi.encodePacked(uint8(0x80), uint8(0x81)), // two dynamic inputs
            0x82, // dynamic output to state[2]
            address(strings)
        );
        commands[1] = _buildCommand(
            Events.logString.selector,
            0x00,
            abi.encodePacked(uint8(0x82)), // dynamic input from state[2]
            0xff,
            address(events)
        );

        bytes[] memory state = new bytes[](3);
        state[0] = _encodeDynamic(bytes("Hello, world!"));
        state[1] = _encodeDynamic(bytes("Hello, world!"));
        state[2] = _encodeDynamic(bytes(""));

        vm.expectEmit(true, false, false, true, address(vm_));
        emit LogString("Hello, world!Hello, world!");

        vm_.execute(commands, state);
    }

    function test_SumArray() public {
        // delegatecall Math.sum([1,2,3]) -> state[1]
        // delegatecall Events.logUint(state[1])

        bytes32[] memory commands = new bytes32[](2);
        commands[0] = _buildCommand(
            Math.sum.selector,
            0x00,
            abi.encodePacked(uint8(0x80)), // dynamic input from state[0]
            0x01, // static output to state[1]
            address(math)
        );
        commands[1] = _buildCommand(
            Events.logUint.selector,
            0x00,
            abi.encodePacked(uint8(0x01)),
            0xff,
            address(events)
        );

        // state[0] = abi encoded uint256[] [1,2,3]
        // For dynamic state, the value should be the raw ABI tail (length + data, no offset pointer)
        uint256[] memory arr = new uint256[](3);
        arr[0] = 1;
        arr[1] = 2;
        arr[2] = 3;

        bytes[] memory state = new bytes[](2);
        // Dynamic state needs to be stored as: length-prefixed raw data (without the offset pointer)
        // The CommandBuilder prepends the offset pointer when building inputs
        // So we store: abi.encode(arr.length) ++ abi.encode(arr[0]) ++ abi.encode(arr[1]) ++ ...
        state[0] = abi.encodePacked(
            uint256(3), // length
            uint256(1),
            uint256(2),
            uint256(3)
        );
        state[1] = abi.encode(uint256(0));

        vm.expectEmit(true, false, false, true, address(vm_));
        emit LogUint(6);

        vm_.execute(commands, state);
    }

    function test_PayableFunction() public {
        uint256 amount = 123 ether;

        // Command 1: valuecall Payable.pay() with value
        // For valuecall (0x03), first index byte is the value slot
        bytes32 cmd1 = _buildCommand(
            Payable.pay.selector,
            0x03, // valuecall
            abi.encodePacked(uint8(0x00)), // state[0] = value; no actual args after that
            0xff,
            address(payable_)
        );

        // Command 2: call Payable.balance() -> state[1]
        bytes32 cmd2 = _buildCommand(
            Payable.balance.selector,
            0x01, // call
            new bytes(0),
            0x01,
            address(payable_)
        );

        // Command 3: delegatecall Events.logUintPayable(state[1])
        bytes32 cmd3 = _buildCommand(
            Events.logUintPayable.selector,
            0x00, // delegatecall
            abi.encodePacked(uint8(0x01)),
            0xff,
            address(events)
        );

        bytes32[] memory commands = new bytes32[](3);
        commands[0] = cmd1;
        commands[1] = cmd2;
        commands[2] = cmd3;

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(amount); // value for pay()
        state[1] = abi.encode(uint256(0));

        vm.deal(address(this), amount);

        vm.expectEmit(true, false, false, true, address(vm_));
        emit LogUint(amount);

        vm_.execute{value: amount}(commands, state);
        assertEq(address(payable_).balance, amount);
    }

    function test_RawStatePassAndReturn() public {
        // Manual command construction matching JS test
        // Command 1: [stateTest, "addSlots", "0x00000102feffff", "0xfe"]
        // Command 2: [events, "logUint", "0x0000ffffffffff", "0xff"]

        // inargs "0x00000102feffff" = flags=0x00, indices=0x000102feffff
        // outargs "0xfe" = IDX_USE_STATE

        bytes32 cmd1 = bytes32(
            abi.encodePacked(
                StateTest.addSlots.selector,
                uint8(0x00), // flags
                uint8(0x00), uint8(0x01), uint8(0x02), uint8(0xfe), uint8(0xff), uint8(0xff), // input indices
                uint8(0xfe), // output: USE_STATE
                address(stateTest)
            )
        );

        bytes32 cmd2 = bytes32(
            abi.encodePacked(
                Events.logUint.selector,
                uint8(0x00), // flags
                uint8(0x00), uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff), // input indices
                uint8(0xff), // no output
                address(events)
            )
        );

        bytes32[] memory commands = new bytes32[](2);
        commands[0] = cmd1;
        commands[1] = cmd2;

        bytes[] memory state = new bytes[](5);
        state[0] = abi.encode(uint256(0)); // dest slot index
        state[1] = abi.encode(uint256(3)); // src1 slot index
        state[2] = abi.encode(uint256(4)); // src2 slot index
        state[3] = abi.encode(uint256(1)); // src1
        state[4] = abi.encode(uint256(2)); // src2

        vm.expectEmit(true, false, false, true, address(vm_));
        emit LogUint(3); // 1 + 2

        vm_.execute(commands, state);
    }

    function test_ERC20Transfer() public {
        uint256 amount = supply / 10;
        address to = address(this);

        // Transfer tokens to the VM
        token.transfer(address(vm_), amount * 3);

        // Command: call token.transfer(to, amount)
        // inargs in JS: "0x010001ffffffff" = flags=0x01, indices=0x0001ffffffff
        // outargs: "0xff"
        bytes32 cmd1 = bytes32(
            abi.encodePacked(
                token.transfer.selector,
                uint8(0x01), // call
                uint8(0x00), uint8(0x01), uint8(0xff), uint8(0xff), uint8(0xff), uint8(0xff),
                uint8(0xff),
                address(token)
            )
        );

        bytes32[] memory commands = new bytes32[](1);
        commands[0] = cmd1;

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(to);
        state[1] = abi.encode(uint256(1));

        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(address(vm_), to, 1);

        vm_.execute(commands, state);
    }

    function test_RevertPropagation() public {
        bytes32 cmd1 = _buildCommand(
            Revert.fail.selector,
            0x00, // delegatecall
            new bytes(0),
            0xff,
            address(reverter)
        );

        bytes32[] memory commands = new bytes32[](1);
        commands[0] = cmd1;

        bytes[] memory state = new bytes[](0);

        vm.expectRevert();
        vm_.execute(commands, state);
    }
}
