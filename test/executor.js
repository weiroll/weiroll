const { expect } = require("chai");
const { ethers } = require("hardhat");
const weiroll = require("@weiroll/weiroll.js");

async function deployLibrary(name) {
  const factory = await ethers.getContractFactory(name);
  const contract = await factory.deploy();
  return weiroll.Contract.createLibrary(contract);
}

describe("Executor", function () {
  const testString = "Hello, world!";

  let events, executor, executorLibrary, math, strings, stateTest;
  let eventsContract;
  let totalGas = 0;

  before(async () => {
    math = await deployLibrary("Math");
    strings = await deployLibrary("Strings");
    
    eventsContract = await (await ethers.getContractFactory("Events")).deploy();
    events = weiroll.Contract.createLibrary(eventsContract);

    const StateTest = await ethers.getContractFactory("StateTest");
    stateTest = await StateTest.deploy();

    const ExecutorLibrary = await ethers.getContractFactory("Executor");
    executorLibrary = await ExecutorLibrary.deploy();

    const Executor = await ethers.getContractFactory("TestableExecutor");
    executor = await Executor.deploy(executorLibrary.address);
  });

  function execute(commands, state) {
    let encodedCommands = commands.map(([target, func, inargs, outargs]) =>
      ethers.utils.concat([
        target.interface.getSighash(func),
        inargs,
        outargs,
        target.address,
      ])
    );
    return executor.execute(encodedCommands, state);
  }

  it("Should not allow direct calls", async () => {
    await expect(executorLibrary.execute([], [])).to.be.reverted;
    await executor.execute([], []); // Expect the wrapped one to not revert with same arguments
  })
  
  it("Should execute a simple addition program", async () => {
    const planner = new weiroll.Planner();
    let a = 1, b = 1;
    for(let i = 0; i < 8; i++) {
      const ret = planner.add(math.add(a, b));
      a = b;
      b = ret;
    }
    planner.add(events.logUint(b));
    const {commands, state} = planner.plan();

    const tx = await executor.execute(commands, state);
    await expect(tx)
      .to.emit(eventsContract.attach(executor.address), "LogUint")
      .withArgs(55);

    const receipt = await tx.wait();
    let gas = receipt.gasUsed.toNumber() - 21000;
    console.log(`Fibonacci: ${gas} gas`);
    totalGas += gas;
  });

  it("Should execute a string length program", async () => {
    const planner = new weiroll.Planner();
    const len = planner.add(strings.strlen(testString));
    planner.add(events.logUint(len));
    const {commands, state} = planner.plan();

    const tx = await executor.execute(commands, state);
    await expect(tx)
      .to.emit(eventsContract.attach(executor.address), "LogUint")
      .withArgs(13);

    const receipt = await tx.wait();
    let gas = receipt.gasUsed.toNumber() - 21000;
    console.log(`String length: ${gas} gas`);
    totalGas += gas;
  });

  it("Should concatenate two strings", async () => {
    const planner = new weiroll.Planner();
    const result = planner.add(strings.strcat(testString, testString));
    planner.add(events.logString(result));
    const {commands, state} = planner.plan();

    const tx = await executor.execute(commands, state);
    await expect(tx)
      .to.emit(eventsContract.attach(executor.address), "LogString")
      .withArgs(testString + testString);

    const receipt = await tx.wait();
    let gas = receipt.gasUsed.toNumber() - 21000;
    console.log(`String concatenation: ${gas} gas`);
    totalGas += gas;
  });

  it("Should sum an array of uints", async () => {
    const planner = new weiroll.Planner();
    const result = planner.add(math.sum([1, 2, 3]));
    planner.add(events.logUint(result));
    const {commands, state} = planner.plan();

    const tx = await executor.execute(commands, state);
    await expect(tx)
      .to.emit(eventsContract.attach(executor.address), "LogUint")
      .withArgs(6);

    const receipt = await tx.wait();
    let gas = receipt.gasUsed.toNumber() - 21000;
    console.log(`Array Sum: ${gas} gas`);
    totalGas += gas;
  });

  it("Should pass and return raw state to functions", async () => {
    const commands = [
      [stateTest, "addSlots", "0x00000102feffff", "0xfe"],
      [events, "logUint", "0x0000ffffffffff", "0xff"]
    ];
    const state = [
      // dest slot index
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      // src1 slot index
      "0x0000000000000000000000000000000000000000000000000000000000000003",
      // src2 slot index
      "0x0000000000000000000000000000000000000000000000000000000000000004",
      // src1
      "0x0000000000000000000000000000000000000000000000000000000000000001",
      // src2
      "0x0000000000000000000000000000000000000000000000000000000000000002"
    ];

    const tx = await execute(commands, state);
    await expect(tx)
      .to.emit(eventsContract.attach(executor.address), "LogUint")
      .withArgs("0x0000000000000000000000000000000000000000000000000000000000000003");

    const receipt = await tx.wait();
    let gas = receipt.gasUsed.toNumber() - 21000;
    console.log(`State passing: ${gas} gas`);
    totalGas += gas;
  });

  after(() => {
    console.log(`Total gas: ${totalGas}`);
  })
});
