const { expect } = require("chai");
const { ethers } = require("hardhat");
const weiroll = require("@weiroll/weiroll.js");

async function deployLibrary(name) {
  const factory = await ethers.getContractFactory(name);
  const contract = await factory.deploy();
  return contract;
  //return weiroll.Contract.fromEthersContract(contract);
}

describe("Executor", function () {

  let events, executor, multiReturn, tupler;

  before(async () => {
    multiReturn = await deployLibrary("MultiReturn");

    tupler = await deployLibrary("LibTupler");

    const Executor = await ethers.getContractFactory("Executor");
    executor = await Executor.deploy();

    events = await (await ethers.getContractFactory("Events")).deploy();
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
  
  it("Should perform a tuple return that's sliced before being fed to another function (first var)", async () => {

    const commands = [
      [multiReturn, "intTuple",      "0x40ffffffffffff", "0x00"],
      [tupler,      "extractElement","0x008001ffffffff", "0x00"],
      [multiReturn, "tupleConsumer", "0x0000ffffffffff", "0xff"]
    ];

    const state = [
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      "0x0000000000000000000000000000000000000000000000000000000000000000",
    ];


    const tx = await execute(commands, state);

    await expect(tx)
      .to.emit(multiReturn.attach(executor.address), "Calculated")
      .withArgs(0xbad); 

    const receipt = await tx.wait();
    console.log(`Tuple return+slice: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should perform a tuple return that's sliced before being fed to another function (second var)", async () => {

    const commands = [
      [multiReturn, "intTuple",      "0x40ffffffffffff", "0x00"],
      [tupler,      "extractElement","0x008001ffffffff", "0x00"],
      [multiReturn, "tupleConsumer", "0x0000ffffffffff", "0xff"]
    ];


    const state = [
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      "0x0000000000000000000000000000000000000000000000000000000000000001",
    ];


    const tx = await execute(commands, state);

    await expect(tx)
      .to.emit(multiReturn.attach(executor.address), "Calculated")
      .withArgs(0xdeed); 

    const receipt = await tx.wait();
    console.log(`Tuple return+slice: ${receipt.gasUsed.toNumber()} gas`);
  });
});
