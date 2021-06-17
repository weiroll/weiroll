const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Executor", function () {
  const testString = "Hello, world!";

  let math;
  let executor;
  let stateTest;

  before(async () => {
    const Math = await ethers.getContractFactory("Math");
    math = await Math.deploy();

    const Strings = await ethers.getContractFactory("Strings");
    strings = await Strings.deploy();

    const StateTest = await ethers.getContractFactory("StateTest");
    stateTest = await StateTest.deploy();

    const Executor = await ethers.getContractFactory("Executor");
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
    let commands = [
      [math, "add", "0x0001ffffffffff", "0x01"],
      [math, "add", "0x0001ffffffffff", "0x00"],
    ];
    // Repeat x4
    commands = commands.concat(commands);
    commands = commands.concat(commands);

    const state = [
      "0x0000000000000000000000000000000000000000000000000000000000000001",
      "0x0000000000000000000000000000000000000000000000000000000000000001",
    ];

    const tx = await execute(commands, state);
    await expect(tx)
      .to.emit(executor, "Executed")
      .withArgs(
        "0x0000000000000000000000000000000000000000000000000000000000000037"
      );

    const receipt = await tx.wait();
    console.log(`Array sum: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should execute a string length program", async () => {
    const commands = [[strings, "strlen", "0x80ffffffffffff", "0x00"]];
    const state = [
      ethers.utils.hexDataSlice(
        ethers.utils.defaultAbiCoder.encode(["string"], [testString]),
        32
      ),
    ];

    const tx = await execute(commands, state);
    await expect(tx)
      .to.emit(executor, "Executed")
      .withArgs(
        "0x000000000000000000000000000000000000000000000000000000000000000d"
      );

    const receipt = await tx.wait();
    console.log(`String concatenation: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should concatenate two strings", async () => {
    const commands = [[strings, "strcat", "0x8080ffffffffff", "0x80"]];
    const state = [
      ethers.utils.hexDataSlice(
        ethers.utils.defaultAbiCoder.encode(["string"], [testString]),
        32
      ),
    ];

    const tx = await execute(commands, state);
    await expect(tx)
      .to.emit(executor, "Executed")
      .withArgs(
        ethers.utils.hexDataSlice(
          ethers.utils.defaultAbiCoder.encode(
            ["string"],
            [testString + testString]
          ),
          32
        )
      );

    const receipt = await tx.wait();
    console.log(`String concatenation: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should sum an array of uints", async () => {
    const commands = [[math, "sum", "0x80ffffffffffff", "0x00"]];
    const state = [
      ethers.utils.hexConcat([
        "0x0000000000000000000000000000000000000000000000000000000000000002",
        "0x1111111111111111111111111111111111111111111111111111111111111111",
        "0x2222222222222222222222222222222222222222222222222222222222222222",
      ]),
    ];

    const tx = await execute(commands, state);
    await expect(tx)
      .to.emit(executor, "Executed")
      .withArgs(
        "0x3333333333333333333333333333333333333333333333333333333333333333"
      );

    const receipt = await tx.wait();
    console.log(`String concatenation: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should pass and return raw state to functions", async () => {
    const commands = [[stateTest, "addSlots", "0x000102feffffff", "0xfe"]];
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
      .to.emit(executor, "Executed")
      .withArgs("0x0000000000000000000000000000000000000000000000000000000000000003");

    const receipt = await tx.wait();
    console.log(`State passing: ${receipt.gasUsed.toNumber()} gas`);
  });
});
