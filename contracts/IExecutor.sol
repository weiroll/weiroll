pragma solidity ^0.8.4;

interface IExecutor {
    function execute(bytes32[] calldata commands, bytes[] memory state) external;
}
