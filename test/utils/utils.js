import { ethers } from "hardhat";
import { Contract } from "@weiroll/weiroll.js";

async function deployLibrary(name) {
    const factory = await ethers.getContractFactory(name);
    const contract = await factory.deploy();
    return Contract.fromEthersContract(contract);
}

export const deployLibrary = deployLibrary;
