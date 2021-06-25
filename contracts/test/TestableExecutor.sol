pragma solidity ^0.8.4;

import "../Executor.sol";

contract TestableExecutor {
    Executor public executor;

    constructor(Executor _executor) {
        executor = _executor;
    }

    function execute(bytes32[] calldata commands, bytes[] memory state)
        public
        returns (bytes[] memory)
    {
        (bool success, bytes memory data) = address(executor).delegatecall(
            abi.encodeWithSelector(Executor.execute.selector, commands, state)
        );
        require(success);

        return abi.decode(data, (bytes[]));
    }
}
