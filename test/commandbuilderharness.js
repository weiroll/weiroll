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
        selector = c.slice(0, 10);
        indices = "0x" + c.slice(10, 10+7*2);
        target = "0x" + c.slice(10+7*2);
        const tx = await cbh.testBuildInputs(state, selector, indices);
        await expect(tx)
          .to.emit(cbh, "BuiltInput")
          .withArgs(selector + abiout.slice(2));
        const receipt = await tx.wait();
        console.log(`buildInputs for ${msg} : ${receipt.gasUsed.toNumber()} gas`);
    }
  }

  it("Should build inputs that match Math.add ABI", async () => {
    const planner = new weiroll.Planner();

    let args = [1, 2];

    abiout = abi.encode(math.interface.getFunction("add").inputs, args);

    planner.addCommand(math.add.apply(this, args));
    planner.addCommand(math.add.apply(this, args));

    const {commands, state} = planner.plan();

    await executeBuildInputs(commands, state, abiout, "Math.add");
  });

  it("Should build inputs that match Strings.strcat ABI", async () => {
    const planner = new weiroll.Planner();

    let args = ["Hello", " World!"];
    let argsEncodable = args.map((s) => ethers.utils.toUtf8Bytes(s))

    abiout = abi.encode(strings.interface.getFunction("strcat").inputs, argsEncodable);

    planner.addCommand(strings.strcat.apply(this, argsEncodable));

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

    const tx = await cbh.testWriteOutputs(state, index, output);

    state[0] = output;

    await expect(tx)
      .to.emit(cbh, "BuiltOutput")
      .withArgs(state, output);
    const receipt = await tx.wait();
    console.log(`buildOutputs for 32byte static state: ${receipt.gasUsed.toNumber()} gas`);

  });

  it("Should select and overwrite second dynamic amount bytes in second state slot given a uint[] output (dynamic test)", async () => {

    let state = [
      "0x000000000000000000000000000000000000000000000000000000000000000a",
      "0x1111111111111111111111111111111111111111111111111111111111111111",
      "0x2222222222222222222222222222222222222222222222222222222222222222"
    ];
    
    let index = "0x81";
    
    let output = abi.encode(["uint[]"], [[1, 2, 3]]);

    const tx = await cbh.testWriteOutputs(state, index, output);

    state[1] = "0x" + output.slice(64+2);

    await expect(tx)
      .to.emit(cbh, "BuiltOutput")
      .withArgs(state, output);
    const receipt = await tx.wait();
    console.log(`buildOutputs for 64 dynamic state: ${receipt.gasUsed.toNumber()} gas`);

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

    const tx = await cbh.testWriteOutputs(state, index, output);

    await expect(tx)
      .to.emit(cbh, "BuiltOutput")
      .withArgs(precoded, output);
    const receipt = await tx.wait();
    console.log(`buildOutputs for 3-element bytes[] rawcall state: ${receipt.gasUsed.toNumber()} gas`);

  });

});
