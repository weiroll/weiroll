const { expect } = require("chai");
const { ethers } = require("hardhat");
const weiroll = require("@weiroll/weiroll.js");

async function deployLibrary(name) {
  const factory = await ethers.getContractFactory(name);
  const contract = await factory.deploy();
  return weiroll.Contract.createLibrary(contract);
}

describe("ERC20", function () {

  let events, vm, erc20;
  let eventsContract;
  let supply = ethers.BigNumber.from("100000000000000000000");
  let amount = supply.div(10);
  let selfAddr = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

  before(async () => {
    erc20 = await deployLibrary("LibERC20");
    
    eventsContract = await (await ethers.getContractFactory("Events")).deploy();
    events = weiroll.Contract.createLibrary(eventsContract);

    /* Deploy token contract */
    tokenContract = await (await ethers.getContractFactory("ExecutorToken")).deploy(supply);

    const VMLibrary = await ethers.getContractFactory("VM");
    const vmLibrary = await VMLibrary.deploy();

    const VM = await ethers.getContractFactory("TestableVM");
    vm = await VM.deploy(vmLibrary.address);

    /* transfer some balance to vm */
    let ttx = await tokenContract.transfer(vm.address, amount.mul(3));
    /* ensure that transfer was successful */
    await expect(ttx).to.emit(tokenContract, "Transfer").withArgs(selfAddr, vm.address, amount.mul(3));
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
    return vm.execute(encodedCommands, state);
  }
  

  it("Should perform an ERC20 transfer", async () => {
    const planner = new weiroll.Planner();

    let token = tokenContract.address;
    let to = selfAddr;

    planner.add(erc20.transfer(token, to, amount));

    const {commands, state} = planner.plan();

    const tx = await vm.execute(commands, state);
    await expect(tx)
      .to.emit(tokenContract, "Transfer")
      .withArgs(vm.address, selfAddr, amount);

    const receipt = await tx.wait();
    console.log(`ERC20 transfer: ${receipt.gasUsed.toNumber()} gas`);
  });

  it("Should perform a DIRECT ERC20 transfer, without using lib", async () => {
    let token = tokenContract.address;
    let to = selfAddr;

    let amt2 = ethers.utils.hexZeroPad(amount.toHexString(), 32);

    const commands = [
      [tokenContract, "transfer", "0x010001ffffffff", "0xff"]
    ];
    const state = [
      // dest slot index
      "0x000000000000000000000000" + to.slice(2) ,
      // amt slot index
      ethers.utils.hexZeroPad("0x01", 32),
      // ret slot index
      "0x0000000000000000000000000000000000000000000000000000000000000000",
    ];

    const tx = await execute(commands, state);
    await expect(tx)
      .to.emit(tokenContract, "Transfer")
      .withArgs(vm.address, selfAddr, "0x1");

    const receipt = await tx.wait();
    console.log(`Direct ERC20 transfer: ${receipt.gasUsed.toNumber()} gas`);
  });
});
