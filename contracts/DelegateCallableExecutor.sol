pragma solidity ^0.8.4;

import "./Executor.sol";

contract DelegateCallableExecutor is Executor {
    address immutable self;

    modifier ensureDelegateCall() {
        require(address(this) != self);
        _;
    }

    constructor() {
        self = address(this);
    }

    function execute(bytes32[] calldata commands, bytes[] memory state)
        public
        ensureDelegateCall
        returns (bytes[] memory)
    {
        return _execute(commands, state);
    }
}
