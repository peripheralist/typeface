/* eslint no-use-before-define: "warn" */
const { ethers } = require("hardhat");
const chalk = require("chalk");
const fs = require("fs");
const { BigNumber } = require("ethers");

const network = process.env.HARDHAT_NETWORK;

const deploy = async (args, owner) => {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Deploying with args:", args);

  const factory = await ethers.getContractFactory("Dreams");

  console.log("Got factory");

  const deployed = await factory.deploy(...args);
  await deployed.deployTransaction.wait();

  console.log("Deployed...");

  const attached = factory.attach(deployed.address);

  console.log("Setting new owner:", owner);
  await attached.transferOwnership(owner);

  const contractName = "Dreams";

  const contract = JSON.parse(
    fs
      .readFileSync(
        `artifacts/contracts/${contractName}.sol/${contractName}.json`
      )
      .toString()
  );

  fs.writeFileSync(
    `deployments/${network}/${contractName}.sol.address`,
    deployed.address
  );

  fs.writeFileSync(
    `deployments/${network}/${contractName}.abi.js`,
    `module.exports = ${JSON.stringify(contract.abi, null, 2)};`
  );

  fs.writeFileSync(
    `deployments/${network}/arguments.js`,
    `module.exports = ${JSON.stringify(args, null, 2)};`
  );

  console.log(
    chalk.green("   Done!"),
    "Deployed at:",
    chalk.magenta(deployed.address)
  );

  return deployed;
};

const projectIds = {
  mainnet: 2, // Juicebox project https://juicebox.money/#/p/tiles
  rinkeby: 423, // Juicebox project https://rinkeby.juicebox.money/#/p/drm
};

const terminalDirectories = {
  mainnet: "0x46C9999A2EDCD5aA177ed7E8af90c68b7d75Ba46",
  rinkeby: "0x88d8c9E98E6EdE75252c2473abc9724965fe7474",
};

const tilesAddresses = {
  mainnet: "0x64931F06d3266049Bf0195346973762E6996D764",
  rinkeby: "0x64931F06d3266049Bf0195346973762E6996D764",
};

const main = async () => {
  const network = process.env.HARDHAT_NETWORK;
  const projectId = projectIds[network];
  const terminalDirectory = terminalDirectories[network];
  const tilesAddress = tilesAddresses[network];
  const baseURI = "https://dreamland.tiles.art/";
  const owner = "0x63A2368F4B509438ca90186cb1C15156713D5834";

  await deploy(
    [
      BigNumber.from(projectId).toHexString(),
      terminalDirectory,
      tilesAddress,
      baseURI,
    ],
    owner
  );

  console.log(
    "⚡️ All contract artifacts saved to:",
    chalk.yellow("packages/hardhat/artifacts/"),
    "\n"
  );

  console.log(
    chalk.green(" ✔ Deployed for network:"),
    process.env.HARDHAT_NETWORK,
    "\n"
  );
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
