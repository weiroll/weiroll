pragma solidity ^0.8.4;

contract Functional {
    function reduce(
        uint[] calldata nums,
        address target,
        bytes4 selector
    ) external returns (uint256) {
        uint256 sum = 0;

        if (nums.length == 0) {
            return 0;
        } else if (nums.length == 1) {
            return nums[0];
        }

        for (uint256 i = 0; i < nums.length; i++) {
            (bool success, bytes memory outdata) = target.delegatecall(
                abi.encodeWithSelector(selector, sum, nums[i])
            );
            require(success, "failed to call reduce target");
            require(outdata.length >= 32, "slicing out of range");
            assembly {
                sum := mload(add(outdata, add(0x20, 0)))
            }
        }

        return sum;
    }
}
