pragma solidity ^0.8.4;

contract LibTupler {
    function extractElement(bytes memory tuple, uint256 index)
        public
        pure
        returns (bytes32)
    {
        assembly {
            mstore(add(tuple, mul(index, 32)), 32)
            return(add(tuple, mul(index, 32)), 64)
        }
    }
}
