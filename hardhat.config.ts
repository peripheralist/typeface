import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-contract-sizer";
import "hardhat-gas-reporter";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";

const coinmarketcapApiKey = process.env.COINMARKETCAP_API_KEY;

module.exports = {
  solidity: {
    version: "0.8.14",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  paths: {
    sources: "./contracts",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 6000000,
  },
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v5",
    alwaysGenerateOverloads: false,
  },
  gasReporter: {
    currency: "USD",
    gasPrice: 20,
    coinmarketcap: coinmarketcapApiKey,
  },
};
