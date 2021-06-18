pragma solidity ^0.8.4;

import "../Executor.sol";

contract TestableExecutor is Executor {

    function execute(bytes32[] calldata commands, bytes[] memory state)
    public
    returns (bytes[] memory)
    {
        return _execute(commands, state);
    }
}

