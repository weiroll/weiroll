const { expect } = require("chai");
const { ethers } = require("hardhat");
const weiroll = require("@weiroll/weiroll.js");

async function deployLibrary(name) {
  const factory = await ethers.getContractFactory(name);
  const contract = await factory.deploy();
  return weiroll.Contract.fromEthersContract(contract);
}

describe("CommandBuilderHarness", function () {
  let cbh;
  let math;
  let strings;
  let abi = ethers.utils.defaultAbiCoder;

  before(async () => {
    const Cbh = await ethers.getContractFactory("CommandBuilderHarness");
    cbh = await Cbh.deploy();

    math = await deployLibrary("Math");
    strings = await deployLibrary("Strings");
  });

  async function executeBuildInputs(commands, state, abiout, msg){
    for (let c of commands) {
        selector = ethers.utils.hexDataSlice(c, 0, 4);
        indices = ethers.utils.hexDataSlice(c, 4, 4+7);
        target = ethers.utils.hexDataSlice(c, 4+7);
        const txBaseGasNoArgs = await cbh.estimateGas.basecall();
        const txBaseGas = await cbh.estimateGas.testBuildInputsBaseGas(state, selector, indices);
        const txGas = await cbh.estimateGas.testBuildInputs(state, selector, indices);
        console.log(`buildInputs gas cost: ${txGas.sub(txBaseGas).toString()} - argument passing cost: ${txBaseGas.sub(txBaseGasNoArgs).toNumber()} - total: ${txGas.toNumber()}`)
        const tx = await cbh.testBuildInputs(state, selector, indices);
        expect(tx).to.equal(selector + abiout.slice(2));
        // console.log(`buildInputs for ${msg} : ${receipt.gasUsed.toNumber()} gas`);
    }
  }

  it("Should build inputs that match Math.add ABI", async () => {
    const planner = new weiroll.Planner();

    let args = [1, 2];

    abiout = abi.encode(math.interface.getFunction("add").inputs, args);

    planner.addCommand(math.add.apply(this, args));

    const {commands, state} = planner.plan();

    await executeBuildInputs(commands, state, abiout, "Math.add");
  });

  it("Should build inputs that match Strings.strcat ABI", async () => {
    const planner = new weiroll.Planner();

    let args = ["Hello", " World!"];

    abiout = abi.encode(strings.interface.getFunction("strcat").inputs, args);

    planner.addCommand(strings.strcat.apply(this, args));

    const {commands, state} = planner.plan();

    await executeBuildInputs(commands, state, abiout, "Strings.strcat");

  });

  it("Should build inputs that match Math.sum ABI", async () => {
    const planner = new weiroll.Planner();

    let args = [
      ethers.BigNumber.from("0xAAA0000000000000000000000000000000000000000000000000000000000002"),
      ethers.BigNumber.from("0x1111111111111111111111111111111111111111111111111111111111111111"),
      ethers.BigNumber.from("0x2222222222222222222222222222222222222222222222222222222222222222")
    ];

    abiout = abi.encode(math.interface.getFunction("sum").inputs, [args]);

    planner.addCommand(math.sum(args));

    const {commands, state} = planner.plan();

    await executeBuildInputs(commands, state, abiout, "Math.sum");

  });

  it("Should select and overwrite first 32 byte slot in state for output (static test)", async () => {

    let state = [
      "0x000000000000000000000000000000000000000000000000000000000000000a",
      "0x1111111111111111111111111111111111111111111111111111111111111111",
      "0x2222222222222222222222222222222222222222222222222222222222222222"
    ];
    
    let index = "0x00";

    let output = "0x0000000000000000000000000000000000000000000000000000000000000000";

    const txBaseGas = await cbh.estimateGas.testWriteOutputsBaseGas(state, index, output);
    const txGas = await cbh.estimateGas.testWriteOutputs(state, index, output);
    console.log("writeOutputs gas cost: ", txGas.sub(txBaseGas).toString())
    const tx = await cbh.testWriteOutputs(state, index, output);

    state[0] = output;

    expect(tx).to.deep.equal([state, output]);
  });

  it("Should select and overwrite second dynamic amount bytes in second state slot given a uint[] output (dynamic test)", async () => {

    let state = [
      "0x000000000000000000000000000000000000000000000000000000000000000a",
      "0x1111111111111111111111111111111111111111111111111111111111111111",
      "0x2222222222222222222222222222222222222222222222222222222222222222"
    ];
    
    let index = "0x81";
    
    let output = abi.encode(["uint[]"], [[1, 2, 3]]);

    const txBaseGas = await cbh.estimateGas.testWriteOutputsBaseGas(state, index, output);
    const txGas = await cbh.estimateGas.testWriteOutputs(state, index, output);
    console.log("writeOutputs gas cost: ", txGas.sub(txBaseGas).toString())
    const tx = await cbh.testWriteOutputs(state, index, output);

    state[1] = ethers.utils.hexDataSlice(output, 32);

    expect(tx).to.deep.equal([state, output]);
  });


  it("Should overwrite entire state with *abi decoded* output value (rawcall)", async () => {

    let state = [
      "0x000000000000000000000000000000000000000000000000000000000000000a",
      "0x1111111111111111111111111111111111111111111111111111111111111111",
      "0x2222222222222222222222222222222222222222222222222222222222222222"
    ];
    
    let index = "0xfe";

    let precoded = ["0x11", "0x22", "0x33"];

    let output = abi.encode(["bytes[]"], [precoded]);

    const txBaseGas = await cbh.estimateGas.testWriteOutputsBaseGas(state, index, output);
    const txGas = await cbh.estimateGas.testWriteOutputs(state, index, output);
    console.log("writeOutputs gas cost: ", txGas.sub(txBaseGas).toString())
    const tx = await cbh.testWriteOutputs(state, index, output);

    expect(tx).to.deep.equal([precoded, output]);
  });

});
