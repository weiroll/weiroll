const { expect } = require("chai");
const { ethers } = require("hardhat");
const weiroll = require("@weiroll/weiroll.js");

async function buildInterface(name, logger) {
  const artifact = await artifacts.readArtifact(name);
  return weiroll.Contract.createLibrary(new ethers.Contract(logger.address, artifact.abi));
}

describe("CommandBuilder", function () {
  let loggerContract, logger, math, strings, executor, baseGas;
  let abi = ethers.utils.defaultAbiCoder;

  before(async () => {
    const Logger = await ethers.getContractFactory("Logger");
    loggerContract = await Logger.deploy();
    logger = await buildInterface("Logger", loggerContract);
    math = await buildInterface("Math", logger);
    strings = await buildInterface("Strings", logger);

    const ExecutorLibrary = await ethers.getContractFactory("Executor");
    const executorLibrary = await ExecutorLibrary.deploy();

    const Executor = await ethers.getContractFactory("TestableExecutor");
    executor = await Executor.deploy(executorLibrary.address);

    const basePlanner = new weiroll.Planner();
    basePlanner.add(logger.logNothing());
    const {commands, state} = basePlanner.plan();
    baseGas = await executor.estimateGas.execute(commands, state);
  });

  async function executeBuildInputs(commands, state, abiout, msg) {
    const tx = executor.execute(commands, state);
    await expect(tx).to.emit(loggerContract.attach(executor.address), "Log").withArgs(abiout);
    const receipt = await (await tx).wait();
    console.log(`buildInputs gas cost: ${receipt.gasUsed.sub(baseGas).toString()}`);
  }

  it("Should build inputs that match Math.add ABI", async () => {
    const planner = new weiroll.Planner();

    let args = [1, 2];

    abiout = math.interface.encodeFunctionData("add", args);

    planner.add(math.add(...args));

    const {commands, state} = planner.plan();

    await executeBuildInputs(commands, state, abiout, "Math.add");
  });

  it("Should build inputs that match Strings.strcat ABI", async () => {
    const planner = new weiroll.Planner();

    let args = ["Hello", " World!"];

    abiout = strings.interface.encodeFunctionData("strcat", args);

    planner.add(strings.strcat(...args));

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

    abiout = math.interface.encodeFunctionData("sum", [args]);

    planner.add(math.sum(args));

    const {commands, state} = planner.plan();

    await executeBuildInputs(commands, state, abiout, "Math.sum");

  });

  // it("Should select and overwrite first 32 byte slot in state for output (static test)", async () => {

  //   let state = [
  //     "0x000000000000000000000000000000000000000000000000000000000000000a",
  //     "0x1111111111111111111111111111111111111111111111111111111111111111",
  //     "0x2222222222222222222222222222222222222222222222222222222222222222"
  //   ];
    
  //   let index = "0x00";

  //   let output = "0x0000000000000000000000000000000000000000000000000000000000000000";

  //   const txBaseGas = await cbh.estimateGas.testWriteOutputsBaseGas(state, index, output);
  //   const txGas = await cbh.estimateGas.testWriteOutputs(state, index, output);
  //   console.log("writeOutputs gas cost: ", txGas.sub(txBaseGas).toString())
  //   const tx = await cbh.testWriteOutputs(state, index, output);

  //   state[0] = output;

  //   expect(tx).to.deep.equal([state, output]);
  // });

  // it("Should select and overwrite second dynamic amount bytes in second state slot given a uint[] output (dynamic test)", async () => {

  //   let state = [
  //     "0x000000000000000000000000000000000000000000000000000000000000000a",
  //     "0x1111111111111111111111111111111111111111111111111111111111111111",
  //     "0x2222222222222222222222222222222222222222222222222222222222222222"
  //   ];
    
  //   let index = "0x81";
    
  //   let output = abi.encode(["uint[]"], [[1, 2, 3]]);

  //   const txBaseGas = await cbh.estimateGas.testWriteOutputsBaseGas(state, index, output);
  //   const txGas = await cbh.estimateGas.testWriteOutputs(state, index, output);
  //   console.log("writeOutputs gas cost: ", txGas.sub(txBaseGas).toString())
  //   const tx = await cbh.testWriteOutputs(state, index, output);

  //   state[1] = ethers.utils.hexDataSlice(output, 32);

  //   expect(tx[0]).to.deep.equal(state);
  // });


  // it("Should overwrite entire state with *abi decoded* output value (rawcall)", async () => {

  //   let state = [
  //     "0x000000000000000000000000000000000000000000000000000000000000000a",
  //     "0x1111111111111111111111111111111111111111111111111111111111111111",
  //     "0x2222222222222222222222222222222222222222222222222222222222222222"
  //   ];
    
  //   let index = "0xfe";

  //   let precoded = ["0x11", "0x22", "0x33"];

  //   let output = abi.encode(["bytes[]"], [precoded]);

  //   const txBaseGas = await cbh.estimateGas.testWriteOutputsBaseGas(state, index, output);
  //   const txGas = await cbh.estimateGas.testWriteOutputs(state, index, output);
  //   console.log("writeOutputs gas cost: ", txGas.sub(txBaseGas).toString())
  //   const tx = await cbh.testWriteOutputs(state, index, output);

  //   expect(tx).to.deep.equal([precoded, output]);
  // });

});
