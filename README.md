# Weiroll

Weiroll is a simple and efficient operation-chaining/scripting language for the EVM.

## Overview

The input to the Weiroll VM is an array of commands and an array of state variables. The Weiroll VM executes the list of commands from start to finish. There is no built-in branching or looping, though these can be added externally.

State elements are `bytes` values of arbitrary length. The VM supports up to 127 state elements.

Commands are `bytes32` values that encode a single operation for the VM to take. Each operation consists of taking zero or more state elements and using them to call (via `delegatecall`) a smart contract function specified in the command. The return value(s) of the function are then unpacked back into the state.

This simple architecture makes it possible for the output of one operation to be used as an input to any other, as well as allowing static values to be supplied by specifying them as part of the initial state.

## Command structure

Each command is a `bytes32` containing the following fields (MSB first):

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
┌───────┬─┬───────────┬─┬───────────────────────────────────────┐
│  sel  │f│    in     │o│              target                   │
└───────┴─┴───────────┴─┴───────────────────────────────────────┘
```

 - `sel` is the 4-byte function selector to call
 - `f` is a flags byte that specifies calltype, and whether this is an extended command
 - `in` is an array of 1-byte argument specifications described below, for the input arguments
 - `o` is the 1-byte argument specification described below, for the return value
 - `target` is the address to call

### Flags

The 1-byte flags argument `f` has the following field structure:

```
  0   1   2   3   4   5   6   7
┌───┬───┬───┬───────────┬────────┐
│tup│ext│dat│ reserved  │calltype│
└───┴───┴───┴───────────┴────────┘
```

If `tup` is set, the return for this command will be assigned to the state slot directly, without any attempt at processing or decoding.

The `ext` bit signifies that this is an extended command, and as such the next command should be treated as 32-byte `in` list of indices, rather than the 6-byte list in the packed command struct.

If `dat` is set, the msg.data will be assigned from the state slot directly, without any attempt at encoding.

Bits 3-5 are reserved for future use.

The 2-bit `calltype` is treated as a `uint16` that specifies the type of call. The value that selects the corresponding call type is described in the table below:

```
   ┌──────┬───────────────────┐
   │ 0x00 │  DELEGATECALL     │
   ├──────┼───────────────────┤
   │ 0x01 │  CALL             │
   ├──────┼───────────────────┤
   │ 0x02 │  STATICCALL       │
   ├──────┼───────────────────┤
   │ 0x03 │  CALL with value  │
   └──────┴───────────────────┘
```

If `calltype` equals `CALL with value`, then the first argument in the `in` input list is taken to be the amount of ETH that will be supplied to the call, and the rest of the arguments are the arguments to the called function, both processed as described below.

### Input/output list (in/o) format


Each 1-byte argument specifier value describes how each input or output argument should be treated, and has the following fields (MSB first):

```
  0   1   2   3   4   5   6   7
┌───┬───────────────────────────┐
│var│           idx             │
└───┴───────────────────────────┘
```

The `var` flag indicates if the indexed value should be treated as fixed- or variable-length. If `var == 0b0`, the argument is fixed-length, and `idx`, is treated as the index into the state array at which the value is located. The state entry at that index must be exactly 32 bytes long (except if overriding msg.data directly via `dat` flag).

If `var == 0b10000000`, the indexed value is treated as variable-length, and `idx` is treated as the index into the state array at which the value is located. The value must be a multiple of 32 bytes long (except if overriding msg.data directly via `dat` flag).

The vm handles the "head" part of ABI-encoding and decoding for variable-length values, so the state elements for these should be the "tail" part of the encoding - for example, a string encodes as a 32 byte length field followed by the string data, padded to a 32-byte boundary, and an array of `uint`s is a 32 byte count followed by the concatenation of all the uints.

There are two special values `idx` can equal to which modify the encoder behavior, specified in the below table:

```
   ┌──────┬───────────────────┐
   │ 0xfe │  USE_STATE        │
   ├──────┼───────────────────┤
   │ 0xff │  END_OF_ARGS      │
   └──────┴───────────────────┘
```

If `idx` equals `USE_STATE` inside of an `in` list byte, then the parameter at that position is constructed by feeding the entire state array into `abi.encode` and passing it to the function as a single argument. If it's specified as part of the `o` output target, then the output of that command is written directly to the state instead via `abi.decode`.

The special `idx` value `END_OF_ARGS` indicates the end of the parameter list, no encoding action will be taken, and all further bytes in the list will be ignored. If the first byte in the input list is `END_OF_ARGS`, then the function will be called with no parameters. If `o` equals `END_OF_ARGS`, then it specifies that the command's return should be ignored.

### Examples

#### Fixed length input and output values

Suppose you want to construct a command to call the following function:

```solidity
function add(uint a, uint b) external returns (uint);
```

`sel` should be set to the function selector for this function, and `target` to the address of the deployed contract containing this function.

`f` should specify this is a delegatecall (`0x00`), `in` needs to specify two input values of fixed length (`var == 0b0`). The remaining four input parameters are unneeded and should be set to `0xff`. Supposing the two inputs should come from state elements 0 and 1, the encoded `in` data is thus `0x000001ffffffff`.

`out` needs to specify that the output value is fixed length (`var == 0b0`). Supposing the output should be written to state element 2, the encoded `out` data is thus `0x02`.

#### Variable length input and output values

Suppose you want to construct a command to call the following function:

```solidity
function concatBytes32(bytes32[] inputs) external returns (bytes);
```

`sel` should be set to the function selector for this function, and `target` to the address of the deployed contract containing this function.

`f` should specify this is a delegatecall (`0x00`), `in` needs to specify one input value of variable length (`var == 0b10000000`), that is an array of 32-byte words (`idx == 0b1000000`). The remaining five input parameters are unneeded and should be set to `0xff`. Supposing the input comes from state element 0, the encoded `in` data is thus `0x00c0ffffffffff`.

`out` needs to specify that the output value is variable length (`var == 0b10000000`). Supposing the output value should be written to state element 1, the encoded `out` data is thus `0x81`.

## Command execution

Command execution takes place in 4 stages:

 1. Command decoding
 2. Input encoding
 3. Call
 4. Output decoding

Command decoding is straightforward and described above in "Command structure".

### Input encoding

Input arguments must be collected from the state and assembled into a valid ABI-encoded string to be passed to the function being called. The vm allocates an array large enough to store the input data. Observing the `var` flag on each input argument specifier, it then either copies the value directly from the relevant state index to the input array, or writes out a pointer to the value, and appends the value to the array. The result is a valid ABI-encoded byte string. The function selector is inserted at the beginning of the input data in this stage.

### Call

Next, the vm calls the target contract with the encoded input data. A `delegatecall` is normally used for vm library contracts, meaning the execution takes place in the vm's context rather than the contract's own, and a normal `call` is used for calling out to external contracts directly (like to an `ERC20.transfer` function). The intention is that users of the executor will themselves `delegatecall` it, meaning that all operations take place in the user's contract's context, or will seem to come directly from a user's contract address for external calls.

### Output decoding

Finally, the return data is decoded by following the output argument specifier, in the same fashion as the 'input encoding' stage. Only one return value is supported.
