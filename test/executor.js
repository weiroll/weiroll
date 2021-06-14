const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Executor", function() {
  let sampleOps;
  let executor;

  before(async () => {
    const SampleOps = await ethers.getContractFactory("SampleOps");
    sampleOps = await SampleOps.deploy();

    const Executor = await ethers.getContractFactory("Executor");
    executor = await Executor.deploy();
  });

  function execute(commands, state) {
    let encodedCommands = commands.map(([target, func, inargs, outargs]) =>
      ethers.utils.concat([target.interface.getSighash(func), inargs, outargs, target.address])
    );
    return executor.execute(encodedCommands, state);
  }

  it("Should execute a simple addition program", async function() {
    let commands = [
      [sampleOps, 'add', '0x0001ffffffff', '0x01ff'],
      [sampleOps, 'add', '0x0001ffffffff', '0x00ff']
    ];
    // Repeat x4
    commands = commands.concat(commands);
    commands = commands.concat(commands);

    const state = [
      "0x0000000000000000000000000000000000000000000000000000000000000001",
      "0x0000000000000000000000000000000000000000000000000000000000000001"
    ];

    const tx = await execute(commands, state);
    await expect(tx).to.emit(executor, 'Executed').withArgs("0x0000000000000000000000000000000000000000000000000000000000000037");

    const receipt = await tx.wait();
    console.log(`Array sum: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should execute a string length program", async function() {
    const commands = [
      [sampleOps, 'strlen', '0x80ffffffffff', '0x00ff']
    ];
    const state = [ethers.utils.toUtf8Bytes("Hello, world!")];
    const tx = await execute(commands, state);
    await expect(tx).to.emit(executor, 'Executed').withArgs("0x000000000000000000000000000000000000000000000000000000000000000d");

    const receipt = await tx.wait();
    console.log(`String concatenation: ${receipt.gasUsed.toNumber()} gas`);
  });
});
