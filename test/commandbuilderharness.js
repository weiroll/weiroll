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

    console.log(commands, state);

    await executeBuildInputs(commands, state, abiout, "Math.add");
  });

  it("Should concatenate two strings", async () => {
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

});
