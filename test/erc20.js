import { expect } from "chai";
import { ethers } from "hardhat";
import { Planner } from "@weiroll/weiroll.js";
import { deployLibrary } from "./utils/utils";

describe("ERC20", function () {

  let events, executor, erc20;
  let tokenContract;
  let supply = ethers.BigNumber.from("100000000000000000000");
  let amount = supply.div(10);
  let selfAddr = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

  before(async () => {
    erc20 = await deployLibrary("ERC20");
    
    events = await deployLibrary("Events")

    /* Deploy token contract */
    tokenContract = await (await ethers.getContractFactory("ExecutorToken")).deploy(supply);

    const Executor = await ethers.getContractFactory("Executor");
    executor = await Executor.deploy();

    /* transfer some balance to executor */
    let ttx = await tokenContract.transfer(executor.address, amount.mul(3));
    /* ensure that transfer was successful */
    await expect(ttx).to.emit(tokenContract, "Transfer").withArgs(selfAddr, executor.address, amount.mul(3));
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
  

  it("Should perform an ERC20 transfer", async () => {
    const planner = new Planner();

    let token = tokenContract.address;
    let to = selfAddr;

    planner.addCommand(erc20.transfer(token, to, amount));

    const {commands, state} = planner.plan();

    commands[0] = commands[0].slice(0, 10) + "00" + commands[0].slice(10, 22)  + commands[0].slice(24)

    const tx = await executor.execute(commands, state);
    await expect(tx)
      .to.emit(tokenContract, "Transfer")
      .withArgs(executor.address, selfAddr, amount);

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
      .withArgs(executor.address, selfAddr, "0x1");

    const receipt = await tx.wait();
    console.log(`Direct ERC20 transfer: ${receipt.gasUsed.toNumber()} gas`);
  });
});
