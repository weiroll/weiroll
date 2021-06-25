const { ethers } = require("hardhat");
const weiroll = require("@weiroll/weiroll.js");

async function deployLibrary(name) {
    const factory = await ethers.getContractFactory(name);
    const contract = await factory.deploy();
    return weiroll.Contract.fromEthersContract(contract);
}

module.exports = {
    deployLibrary: deployLibrary
}