import "@nomiclabs/hardhat-waffle";
import type {HardhatUserConfig} from "hardhat/types";
import "hardhat-gas-reporter"

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
  solidity: "0.8.4",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 21
  }
};
export default userConfig