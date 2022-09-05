const { expect } = require("chai");
const { ethers } = require("hardhat");
const weiroll = require("@weiroll/weiroll.js");

const deploy = async (name) => (await ethers.getContractFactory(name)).deploy();

const deployLibrary = async (name) =>
  weiroll.Contract.createLibrary(await deploy(name));

const deployContract = async (name) =>
  weiroll.Contract.createContract(await deploy(name));

describe("VM", function () {
  const testString = "Hello, world!";

  let events,
    vm,
    math,
    strings,
    stateTest,
    sender,
    revert,
    fallback,
    token,
    payable;
  let supply = ethers.BigNumber.from("100000000000000000000");
  let eventsContract, fallbackContract;

  before(async () => {
    math = await deployLibrary("Math");
    strings = await deployLibrary("Strings");
    sender = await deployLibrary("Sender");
    revert = await deployLibrary("Revert");
    payable = await deployContract("Payable");
    stateTest = await deployContract("StateTest");

    fallbackContract = await (
      await ethers.getContractFactory("Fallback")
    ).deploy();
    fallback = weiroll.Contract.createContract(fallbackContract);

    eventsContract = await (await ethers.getContractFactory("Events")).deploy();
    events = weiroll.Contract.createLibrary(eventsContract);

    const VM = await ethers.getContractFactory("TestableVM");
    vm = await VM.deploy();

    token = await (
      await ethers.getContractFactory("ExecutorToken")
    ).deploy(supply);
  });

  function execute(commands, state, overrides) {
    let encodedCommands = commands.map(([target, func, inargs, outargs]) =>
      ethers.utils.concat([
        func ? target.interface.getSighash(func) : "0x12345678",
        inargs,
        outargs,
        target.address,
      ])
    );
    return vm.execute(encodedCommands, state, { ...overrides });
  }

  it("Should return msg.sender", async () => {
    const [caller] = await ethers.getSigners();
    const planner = new weiroll.Planner();
    const msgSender = planner.add(sender.sender());
    planner.add(events.logAddress(msgSender));

    const { commands, state } = planner.plan();

    const tx = await vm.execute(commands, state);
    await expect(tx)
      .to.emit(eventsContract.attach(vm.address), "LogAddress")
      .withArgs(caller.address);

    const receipt = await tx.wait();
    console.log(`Msg.sender: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should call fallback", async () => {
    const commands = [[fallback, "", "0x2180ffffffffff", "0xff"]];
    const state = ["0x"];

    const tx = await execute(commands, state);
    await expect(tx).to.not.emit(fallbackContract, "LogBytes");

    const receipt = await tx.wait();
    console.log(`fallback: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should call fallback with overriden msg.data and msg.value", async () => {
    const msgValue = ethers.constants.WeiPerEther;
    const msgData = ethers.utils.hexlify(ethers.utils.toUtf8Bytes(testString));

    const commands = [[fallback, "", "0x230081ffffffff", "0xff"]];
    const state = [
      ethers.utils.hexZeroPad(msgValue.toHexString(), "32"),
      msgData,
    ];

    const tx = await execute(commands, state, { value: msgValue });
    await expect(tx).to.emit(fallbackContract, "LogUint").withArgs(msgValue);
    await expect(tx).to.emit(fallbackContract, "LogBytes").withArgs(msgData);

    const receipt = await tx.wait();
    console.log(
      `fallback (override msg.value & msg.data): ${receipt.gasUsed.toNumber()} gas`
    );
  });

  it("Should call function named fallback with msg.value", async () => {
    const planner = new weiroll.Planner();

    const msgValue = ethers.constants.WeiPerEther;
    const data = ethers.utils.hexlify(ethers.utils.toUtf8Bytes(testString));

    planner.add(fallback.fallback(data).withValue(msgValue));

    const { commands, state } = planner.plan();

    const tx = await vm.execute(commands, state, { value: msgValue });
    await expect(tx).to.emit(fallbackContract, "LogUint").withArgs(msgValue);
    await expect(tx).to.emit(fallbackContract, "LogBytes").withArgs(data);

    const receipt = await tx.wait();
    console.log(`fallback (named function): ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should execute a simple addition program", async () => {
    const planner = new weiroll.Planner();
    let a = 1,
      b = 1;
    for (let i = 0; i < 8; i++) {
      const ret = planner.add(math.add(a, b));
      a = b;
      b = ret;
    }
    planner.add(events.logUint(b));
    const { commands, state } = planner.plan();

    const tx = await vm.execute(commands, state);
    await expect(tx)
      .to.emit(eventsContract.attach(vm.address), "LogUint")
      .withArgs(55);

    const receipt = await tx.wait();
    console.log(`Array sum: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should execute a string length program", async () => {
    const planner = new weiroll.Planner();
    const len = planner.add(strings.strlen(testString));
    planner.add(events.logUint(len));
    const { commands, state } = planner.plan();

    const tx = await vm.execute(commands, state);
    await expect(tx)
      .to.emit(eventsContract.attach(vm.address), "LogUint")
      .withArgs(13);

    const receipt = await tx.wait();
    console.log(`String concatenation: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should concatenate two strings", async () => {
    const planner = new weiroll.Planner();
    const result = planner.add(strings.strcat(testString, testString));
    planner.add(events.logString(result));
    const { commands, state } = planner.plan();

    const tx = await vm.execute(commands, state);
    await expect(tx)
      .to.emit(eventsContract.attach(vm.address), "LogString")
      .withArgs(testString + testString);

    const receipt = await tx.wait();
    console.log(`String concatenation: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should sum an array of uints", async () => {
    const planner = new weiroll.Planner();
    const result = planner.add(math.sum([1, 2, 3]));
    planner.add(events.logUint(result));
    const { commands, state } = planner.plan();

    const tx = await vm.execute(commands, state);
    await expect(tx)
      .to.emit(eventsContract.attach(vm.address), "LogUint")
      .withArgs(6);

    const receipt = await tx.wait();
    console.log(`String concatenation: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should execute payable function", async () => {
    const amount = ethers.constants.WeiPerEther.mul(123);
    const planner = new weiroll.Planner();

    planner.add(payable.pay().withValue(amount));
    const balance = planner.add(payable.balance());
    planner.add(
      weiroll.Contract.createContract(eventsContract).logUint(balance)
    );
    const { commands, state } = planner.plan();

    const tx = await vm.execute(commands, state, { value: amount });
    await expect(tx).to.emit(eventsContract, "LogUint").withArgs(amount);
    expect(await ethers.provider.getBalance(payable.address)).to.be.equal(
      amount
    );

    const receipt = await tx.wait();
    console.log(`Payable: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should pass and return raw state to functions", async () => {
    const commands = [
      [stateTest, "addSlots", "0x00000102feffff", "0xfe"],
      [events, "logUint", "0x0000ffffffffff", "0xff"],
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
      "0x0000000000000000000000000000000000000000000000000000000000000002",
    ];

    const tx = await execute(commands, state);
    await expect(tx)
      .to.emit(eventsContract.attach(vm.address), "LogUint")
      .withArgs(
        "0x0000000000000000000000000000000000000000000000000000000000000003"
      );

    const receipt = await tx.wait();
    console.log(`State passing: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should perform a ERC20 transfer", async () => {
    let amount = supply.div(10);
    let to = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

    /* transfer some balance to executor */
    let ttx = await token.transfer(vm.address, amount.mul(3));
    /* ensure that transfer was successful */
    await expect(ttx)
      .to.emit(token, "Transfer")
      .withArgs(to, vm.address, amount.mul(3));

    const commands = [[token, "transfer", "0x010001ffffffff", "0xff"]];
    const state = [
      // dest slot index
      "0x000000000000000000000000" + to.slice(2),
      // amt slot index
      ethers.utils.hexZeroPad("0x01", 32),
      // ret slot index
      "0x0000000000000000000000000000000000000000000000000000000000000000",
    ];

    const tx = await execute(commands, state);
    await expect(tx).to.emit(token, "Transfer").withArgs(vm.address, to, "0x1");

    const receipt = await tx.wait();
    console.log(`Direct ERC20 transfer: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should propagate revert reasons", async () => {
    const planner = new weiroll.Planner();

    planner.add(revert.fail());
    const { commands, state } = planner.plan();

    await expect(vm.execute(commands, state)).to.be.revertedWith(
      "Hello World!"
    );
  });
});
