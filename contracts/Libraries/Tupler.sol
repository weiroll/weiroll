pragma solidity ^0.8.4;

contract LibTupler {
    function extractElement(bytes memory tuple, uint256 index)
        public
        pure
        returns (bytes32)
    {
        assembly {
            return(add(tuple, mul(add(index, 1), 32)), 32)
        }
    }
}
