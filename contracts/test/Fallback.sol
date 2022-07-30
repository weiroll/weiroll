// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../Libraries/Events.sol";

contract Fallback is Events {
    fallback() external payable {
        if (msg.value > 0) emit LogUint(msg.value);
        if (msg.data.length > 0) emit LogBytes(msg.data);
    }

    function fallback(bytes calldata data) external payable {
        if (msg.value > 0) emit LogUint(msg.value);
        if (data.length > 0) emit LogBytes(data);
    }
}
