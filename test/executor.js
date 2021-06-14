const { expect } = require("chai");

describe("Executor", function() {
  let sampleOps;
  let executor;

  before(async () => {
    const SampleOps = await ethers.getContractFactory("SampleOps");
    sampleOps = await SampleOps.deploy();

    const Executor = await ethers.getContractFactory("Executor");
    executor = await Executor.deploy();
  });

  it("Should execute a simple addition program", async function() {
    let commands = [
      ethers.utils.concat([sampleOps.interface.getSighash('add'), '0x0001ffffffff', '0x00ff', sampleOps.address]),
      ethers.utils.concat([sampleOps.interface.getSighash('add'), '0x0001ffffffff', '0x01ff', sampleOps.address])
    ];
    // Repeat x4
    commands = commands.concat(commands);
    commands = commands.concat(commands);

    const state = [1, 1];
    const tx = await executor.execute(commands, state);
    const receipt = await tx.wait();
    expect(receipt.status).to.equal(1);
    console.log(`Array sum: ${receipt.gasUsed.toNumber()} gas`);
  });
});
