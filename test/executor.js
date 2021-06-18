const { expect } = require("chai");
const { ethers } = require("hardhat");
const weiroll = require("@weiroll/weiroll.js");

async function deployLibrary(name) {
  const factory = await ethers.getContractFactory(name);
  const contract = await factory.deploy();
  return weiroll.Contract.fromEthersContract(contract);
}

describe("Executor", function () {
  const testString = "Hello, world!";

  let events, executor, math, strings, stateTest;
  let eventsContract;

  before(async () => {
    math = await deployLibrary("Math");
    strings = await deployLibrary("Strings");
    
    eventsContract = await (await ethers.getContractFactory("Events")).deploy();
    events = weiroll.Contract.fromEthersContract(eventsContract);

    const StateTest = await ethers.getContractFactory("StateTest");
    stateTest = await StateTest.deploy();

    const Executor = await ethers.getContractFactory("TestableExecutor");
    executor = await Executor.deploy();
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
  
  it("Should execute a simple addition program", async () => {
    const planner = new weiroll.Planner();
    let a = 1, b = 1;
    for(let i = 0; i < 8; i++) {
      const ret = planner.addCommand(math.add(a, b));
      a = b;
      b = ret;
    }
    planner.addCommand(events.logUint(b));
    const {commands, state} = planner.plan();

    const tx = await executor.execute(commands, state);
    await expect(tx)
      .to.emit(eventsContract.attach(executor.address), "LogUint")
      .withArgs(55);

    const receipt = await tx.wait();
    console.log(`Array sum: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should execute a string length program", async () => {
    const planner = new weiroll.Planner();
    const len = planner.addCommand(strings.strlen(testString));
    planner.addCommand(events.logUint(len));
    const {commands, state} = planner.plan();

    const tx = await executor.execute(commands, state);
    await expect(tx)
      .to.emit(eventsContract.attach(executor.address), "LogUint")
      .withArgs(13);

    const receipt = await tx.wait();
    console.log(`String concatenation: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should concatenate two strings", async () => {
    const planner = new weiroll.Planner();
    const result = planner.addCommand(strings.strcat(testString, testString));
    planner.addCommand(events.logString(result));
    const {commands, state} = planner.plan();

    const tx = await executor.execute(commands, state);
    await expect(tx)
      .to.emit(eventsContract.attach(executor.address), "LogString")
      .withArgs(testString + testString);

    const receipt = await tx.wait();
    console.log(`String concatenation: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should sum an array of uints", async () => {
    const planner = new weiroll.Planner();
    const result = planner.addCommand(math.sum([1, 2, 3]));
    planner.addCommand(events.logUint(result));
    const {commands, state} = planner.plan();

    const tx = await executor.execute(commands, state);
    await expect(tx)
      .to.emit(eventsContract.attach(executor.address), "LogUint")
      .withArgs(6);

    const receipt = await tx.wait();
    console.log(`String concatenation: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should pass and return raw state to functions", async () => {
    const commands = [
      [stateTest, "addSlots", "0x000102feffffff", "0xfe"],
      [events, "logUint", "0x00ffffffffffff", "0xff"]
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
    console.log(`State passing: ${receipt.gasUsed.toNumber()} gas`);
  });
});
