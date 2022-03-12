require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-deploy");
require("hardhat-deploy-ethers");

const fs = require("fs");

function mnemonic() {
  try {
    return fs.readFileSync("./mnemonic.txt").toString().trim();
  } catch (e) {
    console.log("Couldn't read mnemonic", e);
  }
  return "";
}

function deployerPk() {
  try {
    return fs.readFileSync("./pk.txt").toString().trim();
  } catch (e) {
    console.log("Couldn't read pk", e);
  }
  return "";
}

const infuraId = "643e4d7aeffa4bd1b56c33e0c99b7604";

module.exports = {
  networks: {
    hardhat: {
      chainId: 1337,
      accounts: [
        {
          privateKey:
            "c6cbd7d76bc5baca530c875663711b947efa6a86a900a9e8645ce32e5821484e",
          balance: "100000000000000000000000",
        },
      ],
    },
    localhost: {
      url: "http://localhost:8545",
    },
    kovan: {
      url: "https://kovan.infura.io/v3/" + infuraId,
      accounts: {
        mnemonic: mnemonic(),
      },
    },
    rinkeby: {
      url: "https://rinkeby.infura.io/v3/" + infuraId,
      accounts: [deployerPk()],
    },
    mainnet: {
      url: "https://mainnet.infura.io/v3/" + infuraId,
      accounts: [deployerPk()],
      gasPrice: 110000000000,
    },
  },
  etherscan: {
    apiKey: {
      // rinkeby: `5NE8T9T1Q6PT9DTHC5DTB8GU4BK76W7SMQ`,
      mainnet: `5NE8T9T1Q6PT9DTHC5DTB8GU4BK76W7SMQ`,
      // mainnet: `${process.env.ETHERSCAN_API_KEY}`,
    },
  },
  solidity: {
    version: "0.8.12",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  namedAccounts: {
    deployer: 0,
    dev: 1,
    fee: 2,
  },
  paths: {
    sources: "./contracts",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 200000,
  },
};
