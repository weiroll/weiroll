
pragma solidity ^0.8.11;

import { VM } from './VM.sol';

contract BoundWeiroll is VM {
    address immutable public owner;

    constructor(address owner_) {
        owner = owner_;
    }

    function execute(bytes32[] calldata commands, bytes[] memory state)
      external returns (bytes[] memory) {
        require(msg.sender == owner, 'ERR_OWNER');
    }
}

contract BuilderBoundWeiroll is BoundWeiroll {
    constructor() BoundWeiroll(msg.sender) {}
}