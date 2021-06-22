pragma solidity ^0.8.4;

contract MultiReturn{

    event Calculated(uint256 j);

    function intTuple() public view returns (uint, uint) {
        return 0xbad, 0xdeed
    }

    function tupleConsumer(uint arg) public view returns (uint) {
        emit Calculated(arg);
    }

}
