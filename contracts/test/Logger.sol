pragma solidity ^0.8.4;

// Simple contract that logs its input
contract Logger {
    event Log(bytes data);

    function logNothing() external {
        emit Log("");
    }

    fallback() external {
        emit Log(msg.data);
    }
}