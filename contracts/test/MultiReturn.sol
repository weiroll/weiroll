pragma solidity ^0.8.4;

contract MultiReturn {
    event Calculated(uint256 j);

    function intTuple()
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (0xbad, 0xdeed, 0xcafe);
    }

    function tupleConsumer(uint256 arg) public returns (uint256) {
        emit Calculated(arg);
    }
}
