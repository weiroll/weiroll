import "@nomiclabs/hardhat-waffle";
import type {HardhatUserConfig} from "hardhat/types";

const userConfig: HardhatUserConfig = {
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 2000000,
  },
  solidity: "0.8.11",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
  }
};
export default userConfig