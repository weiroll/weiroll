const { expect } = require("chai");
const { ethers } = require("hardhat");
const weiroll = require("@weiroll/weiroll.js");

async function deployLibrary(name) {
  const factory = await ethers.getContractFactory(name);
  const contract = await factory.deploy();
  return weiroll.Contract.fromEthersContract(contract);
}

describe("Executor", function () {

  let events, executor, erc20;
  let eventsContract;
  let supply = ethers.BigNumber.from("100000000000000000000");
  let amount = supply.div(10);
  let selfAddr = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

  before(async () => {
    erc20 = await deployLibrary("ERC20Ops");
    
    eventsContract = await (await ethers.getContractFactory("Events")).deploy();
    events = weiroll.Contract.fromEthersContract(eventsContract);

    /* Deploy token contract */
    tokenContract = await (await ethers.getContractFactory("ExecutorToken")).deploy(supply);

    const Executor = await ethers.getContractFactory("Executor");
    executor = await Executor.deploy();

    /* transfer some balance to executor */
    let ttx = await tokenContract.transfer(executor.address, amount);
    /* ensure that transfer was successful */
    await expect(ttx).to.emit(tokenContract, "Transfer").withArgs(selfAddr, executor.address, amount);
  });

  it("Should perform an ERC20 transfer", async () => {
    const planner = new weiroll.Planner();

    let token = tokenContract.address;
    let to = selfAddr;

    planner.addCommand(erc20.transfer(token, to, amount));

    const {commands, state} = planner.plan();

    const tx = await executor.execute(commands, state);
    await expect(tx)
      .to.emit(tokenContract, "Transfer")
      .withArgs(executor.address, selfAddr, amount);

    const receipt = await tx.wait();
    console.log(`ERC20 transfer: ${receipt.gasUsed.toNumber()} gas`);
  });
});
