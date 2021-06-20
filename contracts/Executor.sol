pragma solidity ^0.8.4;

import "./CommandBuilder.sol";

uint8 constant CT_DELEGATECALL = 0x00;
uint8 constant CT_CALL = 0x01;
uint8 constant CT_STATICCALL = 0x02;
uint8 constant CT_VALUECALL = 0x03;

contract Executor {
    using CommandBuilder for bytes[];

    function execute(bytes32[] calldata commands, bytes[] memory state)
        public
        returns (bytes[] memory)
    {
        for (uint256 i = 0; i < commands.length; i++) {
            bytes32 command = commands[i];

            uint8 calltype = uint8(bytes1(command << 32));

            bool success;
            bytes memory outdata;

            if (calltype == CT_DELEGATECALL){
                (success, outdata) = // target
                address(uint160(uint256(command))).delegatecall(
                    // inputs
                    state.buildInputs(
                        //selector
                        bytes4(command),
                        bytes6(command << 40)
                    )
                );
            }
            else if (calltype == CT_CALL){
                (success, outdata) = // target
                address(uint160(uint256(command))).call(
                    // inputs
                    state.buildInputs(
                        //selector
                        bytes4(command),
                        bytes6(command << 40)
                    )
                );
            }
            else if (calltype == CT_STATICCALL){
                (success, outdata) = // target
                address(uint160(uint256(command))).staticcall(
                    // inputs
                    state.buildInputs(
                        //selector
                        bytes4(command),
                        bytes6(command << 40)
                    )
                );
            }
            else if (calltype == CT_VALUECALL){
                uint256 calleth;
                bytes memory v = state[uint8(bytes1(command << 40))];
                assembly {
                    mstore(add(calleth, 0x20), v)
                }
                (success, outdata) = // target
                address(uint160(uint256(command))).call{value: calleth}(
                    // inputs
                    state.buildInputs(
                        //selector
                        bytes4(command),
                        bytes6(uint48(bytes6(command << 48)) | 0xFF)
                    )
                );
            }
            else {
                revert("Invalid calltype");
            }

            require(success, "Call failed");
            state = state.writeOutputs(bytes1(command << 88), outdata);
        }
        return state;
    }
}
