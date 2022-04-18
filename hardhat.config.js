const { subtask } = require("hardhat/config");
const { TASK_COMPILE_SOLIDITY_GET_COMPILER_INPUT, TASK_COMPILE_SOLIDITY_EMIT_ARTIFACTS } = require("hardhat/builtin-tasks/task-names");
const { utils } = require("ethers");
const { access, readFile } = require("fs/promises");

require("@nomiclabs/hardhat-waffle");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

subtask(TASK_COMPILE_SOLIDITY_GET_COMPILER_INPUT)
  .setAction(
    async ({compilationJob}) => {
      const input = await runSuper();
      const config = compilationJob.getSolcConfig();
      if(config?.settings?.language !== undefined) {
        input.language = config.settings.language;
        delete config.settings.language;
      }
      return input;
    }
  );

subtask(TASK_COMPILE_SOLIDITY_EMIT_ARTIFACTS)
  .setAction(
    async ({compilationJob, input, output, solcBuild}) => {
      for(const sourceName in output.contracts) {
        for(const contractName in output.contracts[sourceName]) {
          const config = output.contracts[sourceName][contractName];
          if(config.abi === undefined) {
            const abiFilename = `${sourceName.split('.').slice(0, -1).join('.')}:${contractName}.abi.json`;
            try {
              await access(abiFilename);
              const abi = await readFile(abiFilename)
              config.abi = JSON.parse(abi);
            } catch { }
          }
        }
      }
      return await runSuper();
    }
  );

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: '0.8.13',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
    overrides: {
      "contracts/Executor.sol": {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 900000
          },
          language: "Yul"
        }
      }
    }
  }
};

