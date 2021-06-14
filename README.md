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
┌───────────────────────────────────────────────────────────────┐
│  sel  |    in     |out|              target                   │
└───────────────────────────────────────────────────────────────┘
```

 - `sel` is the 4-byte function selector to call
 - `in` is an array of 1-byte argument specifications described below, for the input arguments
 - `out` is an array of 1-byte argument specifications described below, for the return values
 - `target` is the address to call

The 1-byte argument specifier values describe how each input or output argument should be treated, and have the following fields (MSB first):

```
  0   1   2   3   4   5   6   7
┌───┬───────────────────────────┐
│var│           idx             │
└───┴───────────────────────────┘
```

The `var` flag indicates if the indexed value should be treated as fixed- or variable-length. If `var == 0b`, the argument is fixed-length, and the remainder of the value, `data`, is treated as the index into the state array at which the value is located.

If `var == 1b`, the indexed value is treated as variable-length, and the remainder of the field is interpreted differently:

```
  0   1   2   3   4   5   6   7
┌───┬───┬───────────────────────┐
│ 1 │ws │         idx           │
└───┴───┴───────────────────────┘
```

The `ws` (word size) flag indicates if the variable length data being referenced is an array of bytes (`ws == 0b`) or an array of 32-byte words (`ws == 1b`). The remaining 6 bits are the index in the state array at which the value can be found.

The executor handles ABI-encoding and decoding for variable-length values, so the state elements for these should simply be the value itself - for example, a string is supplied without a length prefix, and an array of `uint`s is simply the concatenation of all the uints.

The special value `0xff` for an argument specifier indicates that the parameter is not required, and no action should be taken.

### Examples

#### Fixed length input and output values

Suppose you want to construct a command to call the following function:

```
function add(uint a, uint b) external returns(uint);
```

`sel` should be set to the function selector for this function, and `target` to the address of the deployed contract containing this function.

`in` needs to specify two input values of fixed length (`var == 0b`). The remaining four input parameters are unneeded and should be set to `0xff`. Supposing the two inputs should come from state elements 0 and 1, the encoded `in` data is thus `0x0001ffffffff`.

`out` needs to specify one output value of fixed length (`var == 0b`). The other output value is unneeded and should be set to `0xff`. Supposing the output should be written to state element 2, the encoded `out` data is thus `0x02ff`.

#### Variable length input and output values

Suppose you want to construct a command to call the following function:

```
function concatBytes32(bytes32[] inputs) external returns(bytes);
```

`sel` should be set to the function selector for this function, and `target` to the address of the deployed contract containing this function.

`in` needs to specify one input value of variable length (`var == 1b`), that is an array of 32-byte words (`ws == 1b`). The remaining five input parameters are unneeded and should be set to `0xff`. Supposing the input comes from state element 0, the encoded `in` data is thus `0xc0ffffffffff`.

`out` needs to specify one output value of variable length (`var == 1b`), that is an array of bytes (`ws == 0b`). The remaining output value is unneeded and should be set to `0xff`. Supposing the output value should be written to state element `, the encoded `out` data is thus `0x81ff`.

## Command execution

Command execution takes place in 4 stages:

 1. Command decoding
 2. Input encoding
 3. Call
 4. Output decoding

Command decoding is straightforward and described above in "Command structure".

### Input encoding

Input arguments must be collected from the state and assembled into a valid ABI-encoded string to be passed to the function being called. The executor allocates an array large enough to store the input data. Observing the `var` and `ws` flags on each input argument specifier, it then either copies the value directly from the relevant state index to the input array, or writes out a pointer to the value, and appends the value to the array. The result is a valid ABI-encoded byte string. The function selector is inserted at the beginning of the input data in this stage.

### Call

Next, the executor calls the target contract with the encoded input data. A `delegatecall` is used, meaning the execution takes place in the executor's context rather than the contract's own. The intention is that users of the executor will themselves `delegatecall` it, meaning that all operations take place in the user's contract's context.

### Output decoding

Finally, the return data is decoded by following the output argument specifiers, in the same fashion as the 'input encoding' stage. Up to two return values are supported.
