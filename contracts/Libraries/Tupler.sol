pragma solidity ^0.8.4;

contract LibTupler {
    function tupleSlicer(
        uint256 offset,
        uint256 size,
        bytes memory slot
    ) external returns (bytes memory) {
        bytes memory ret = new bytes(size);

        memcpy(slot, offset, ret, 0, size);

        uint256 rsz = size + 32;
        assembly {
            return(ret, rsz)
        }
    }

    function memcpy(
        bytes memory src,
        uint256 srcidx,
        bytes memory dest,
        uint256 destidx,
        uint256 len
    ) internal view {
        assembly {
            pop(
                staticcall(
                    gas(),
                    4,
                    add(add(src, 32), srcidx),
                    len,
                    add(add(dest, 32), destidx),
                    len
                )
            )
        }
    }
}
