require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-web3")
require("hardhat-gas-reporter")
require('hardhat-contract-sizer');

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: '0.8.0',
      }
    ],
    
    settings: {
      optimizer: {
        enabled: true,
        runs: 2000
      }
    }
  },

  networks: {
    hardhat: {
      accounts: {
        count: 3000
      },
      gasPrice: 1000000000
    }
  }
};
