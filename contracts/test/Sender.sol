pragma solidity ^0.8.4;

contract Sender {
  function sender() public view returns (address) {
    return msg.sender;
  }
}
