const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Executor", function() {
  const testString = "Hello, world!";
  
  let math;
  let executor;
    
  let abiCoder = ethers.utils.defaultAbiCoder

  before(async () => {
    const Math = await ethers.getContractFactory("Math");
    math = await Math.deploy();

    const Strings = await ethers.getContractFactory("Strings");
    strings = await Strings.deploy();

    const Functional = await ethers.getContractFactory("Functional");
    functional = await Functional.deploy();

    const Executor = await ethers.getContractFactory("Executor");
    executor = await Executor.deploy();

    const CommandBuilderHarness = await ethers.getContractFactory("CommandBuilderHarness");
    commandbuilderharness = await CommandBuilderHarness.deploy();
  });

  function execute(commands, state) {
    let encodedCommands = commands.map(([target, func, inargs, outargs]) =>
      ethers.utils.concat([target.interface.getSighash(func), inargs, outargs, target.address])
    );
    console.log([encodedCommands.map((x) => ethers.utils.hexlify(x)), state])
    return executor.execute(encodedCommands, state);
  }

  function executeHarness(commands, state) {
    let encodedCommands = commands.map(([target, func, inargs, outargs]) =>
      ethers.utils.concat([target.interface.getSighash(func), inargs, outargs, target.address])
    );
    return commandbuilderharness.testBuildInputs(encodedCommands, state);
  }

  it("Should execute a simple addition program", async () => {
    let commands = [
      [math, 'add', '0x0001ffffffff', '0x01ff'],
      [math, 'add', '0x0001ffffffff', '0x00ff']
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

  it("Should execute a string length program", async () => {
    const commands = [
      [strings, 'strlen', '0x80ffffffffff', '0x00ff']
    ];
    const state = [ethers.utils.toUtf8Bytes(testString)];

    const tx = await execute(commands, state);
    await expect(tx).to.emit(executor, 'Executed').withArgs("0x000000000000000000000000000000000000000000000000000000000000000d");

    const receipt = await tx.wait();
    console.log(`String length: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should concatenate two strings", async () => {
    const commands = [
      [strings, 'strcat', '0x8080ffffffff', '0x80ff']
    ];
    const state = [ethers.utils.toUtf8Bytes(testString)];

    const tx = await execute(commands, state);
    await expect(tx).to.emit(executor, 'Executed').withArgs(ethers.utils.hexlify(ethers.utils.toUtf8Bytes(testString + testString)));

    const receipt = await tx.wait();
    console.log(`String concatenation: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should sum an array of uints", async () => {
    const commands = [
      [math, 'sum', '0xC0ffffffffff', '0x00ff']
    ];
    const state = ["0x11111111111111111111111111111111111111111111111111111111111111112222222222222222222222222222222222222222222222222222222222222222"];

    const tx = await execute(commands, state);
    await expect(tx).to.emit(executor, 'Executed').withArgs('0x3333333333333333333333333333333333333333333333333333333333333333');

    const receipt = await tx.wait();
    console.log(`Array sum: ${receipt.gasUsed.toNumber()} gas`);
  });


  it("Should produce an input for (uint[],address,bytes4)", async () => {
    const commands = [
      [functional, 'reduce', '0xC00102ffffff', '0x00ff']
    ];
    const ar = ["0x1111111111111111111111111111111111111111111111111111111111111111", "0x2222222222222222222222222222222222222222222222222222222222222222"];
    //const state = [ar, math.address, math.interface.getSighash('add')];
    const state = [
      ethers.utils.hexConcat(ar),
      String(ethers.utils.hexZeroPad(math.address, 32)),
      String(ethers.utils.hexConcat([math.interface.getSighash('add'), '0x00000000000000000000000000000000000000000000000000000000']))
    ];
    //const state = [ethers.utils.hexlify(abiCoder.encode(["uint[]"], [[1, 2]])), math.address, math.interface.getSighash('add')];

    console.log(`State built: ${state}`);
    console.log(`Target: ${functional.address}`);

    const expected = ethers.utils.hexConcat([
      functional.interface.getSighash('reduce'),
      ethers.utils.defaultAbiCoder.encode(['uint[]', 'address', 'bytes4'], [ar, math.address, math.interface.getSighash('add')])
    ]);

    const tx = await executeHarness(commands, state);
    
    await expect(tx).to.emit(commandbuilderharness, 'BuiltInput').withArgs(
      functional.address,
      expected
    );

    const receipt = await tx.wait();
    console.log(`Uint reduce (add): ${receipt.gasUsed.toNumber()} gas`);

    const tx2 = await (await ethers.getSigners())[0].sendTransaction({
      to: functional.address,
      data: expected
    })
    const receipt2 = await tx2.wait();
    console.log(receipt2);
  });

  it("Should reduce a flat array of uints given a reducing target function", async () => {
    const commands = [
      [functional, 'reduce', '0xC00102ffffff', '0x00ff']
    ];
    const ar = ["0x1111111111111111111111111111111111111111111111111111111111111111", "0x2222222222222222222222222222222222222222222222222222222222222222"];
    //const state = [ar, math.address, math.interface.getSighash('add')];
    const state = [
      ethers.utils.hexConcat(ar),
      String(ethers.utils.hexZeroPad(math.address, 32)),
      String(ethers.utils.hexConcat([math.interface.getSighash('add'), '0x00000000000000000000000000000000000000000000000000000000']))
    ];
    //const state = [ethers.utils.hexlify(abiCoder.encode(["uint[]"], [[1, 2]])), math.address, math.interface.getSighash('add')];

    console.log(`State built: ${state}`);

    const tx = await execute(commands, state);
    await expect(tx).to.emit(executor, 'Executed').withArgs('0x3333333333333333333333333333333333333333333333333333333333333333');

    const receipt = await tx.wait();
    console.log(`Uint reduce (add): ${receipt.gasUsed.toNumber()} gas`);
  });
});
