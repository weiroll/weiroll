// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../VM.sol";

contract TestableVM {
    VM public vm;

    constructor(VM _vm) {
        vm = _vm;
    }

    function execute(bytes32[] calldata commands, bytes[] memory state)
        public
        returns (bytes[] memory)
    {
        (bool success, bytes memory data) = address(vm).delegatecall(
            abi.encodeWithSelector(VM.execute.selector, commands, state)
        );
        
        if (!success) {
            assembly {
                revert(add(32, data), mload(data))
            }
        }

        return abi.decode(data, (bytes[]));
    }
}
