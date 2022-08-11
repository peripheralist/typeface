/* eslint no-use-before-define: "warn" */
import chalk from "chalk";
import { keccak256 } from "ethers/lib/utils";
import fs from "fs";
import { ethers } from "hardhat";

import { fonts } from "../fonts";
import { reservedColors } from "../reservedColors";
import {
  CapsulesMetadata,
  CapsulesToken,
  CapsulesTypeface,
} from "../typechain-types";

const network = process.env.HARDHAT_NETWORK;
// const ownerAddress = "0x63A2368F4B509438ca90186cb1C15156713D5834";
const ownerAddress = "0x817738DC393d682Ca5fBb268707b99F2aAe96baE";
const feeReceiverAddress = "0x817738DC393d682Ca5fBb268707b99F2aAe96baE";

const getDeployer = async () => (await ethers.getSigners())[0];

const writeFiles = (
  contractName: string,
  contractAddress: string,
  args: string[]
) => {
  const contract = JSON.parse(
    fs
      .readFileSync(
        `artifacts/contracts/${contractName}.sol/${contractName}.json`
      )
      .toString()
  );

  fs.writeFileSync(
    `deployments/${network}/${contractName}.json`,
    `{
      "address": "${contractAddress}", 
      "abi": ${JSON.stringify(contract.abi, null, 2)}
  }`
  );

  fs.writeFileSync(
    `deployments/${network}/${contractName}.arguments.js`,
    `module.exports = [${args}];`
  );

  console.log(
    "⚡️ All contract artifacts saved to:",
    chalk.yellow(`deployments/${network}/${contractName}`),
    "\n"
  );
};

const deployCapsulesTypeface = async (
  capsulesTokenAddress: string
): Promise<CapsulesTypeface> => {
  const deployer = await getDeployer();
  const _fonts = Object.keys(fonts).map((weight) => ({
    weight: parseInt(weight) as keyof typeof fonts,
    style: "normal",
  }));
  const hashes = Object.values(fonts).map((font) =>
    keccak256(Buffer.from(font))
  );

  console.log("Deploying CapsulesTypeface with the account:", deployer.address);

  const args = [_fonts, hashes, capsulesTokenAddress];

  console.log("Deploying with args:", args);

  const CapsulesTypefaceFactory = await ethers.getContractFactory(
    "CapsulesTypeface"
  );
  const capsulesTypeface = (await CapsulesTypefaceFactory.deploy(
    ...args
  )) as CapsulesTypeface;

  console.log(
    chalk.green(` ✔ CapsulesTypeface deployed for network:`),
    process.env.HARDHAT_NETWORK,
    "\n",
    chalk.magenta(capsulesTypeface.address),
    `tx: ${capsulesTypeface.deployTransaction.hash}`
  );

  writeFiles(
    "CapsulesTypeface",
    capsulesTypeface.address,
    args.map((a) => JSON.stringify(a))
  );

  return capsulesTypeface;
};

export async function deployCapsulesMetadata(capsulesTypefaceAddress: string) {
  const deployer = await getDeployer();
  console.log("Deploying CapsulesMetadata with the account:", deployer.address);

  const CapsulesMetadata = await ethers.getContractFactory("CapsulesMetadata");

  const args = [
    capsulesTypefaceAddress
  ]

  const capsulesMetadata = (await CapsulesMetadata.deploy(
    ...args
  )) as CapsulesMetadata;

  console.log(
    chalk.green(` ✔ CapsulesMetadata deployed for network:`),
    process.env.HARDHAT_NETWORK,
    "\n",
    chalk.magenta(capsulesMetadata.address),
    `tx: ${capsulesMetadata.deployTransaction.hash}`
  );

  writeFiles(
    "CapsulesMetadata",
    capsulesMetadata.address,
    args.map((a) => JSON.stringify(a))
  );

  return capsulesMetadata;
}

const deployCapsulesToken = async (
  capsulesTypefaceAddress: string,
  capsulesMetadataAddress: string,
): Promise<CapsulesToken> => {
  const deployer = await getDeployer();
  console.log("Deploying CapsulesToken with the account:", deployer.address);

  const royalty = 50;

  const args = [
    capsulesTypefaceAddress,
    capsulesMetadataAddress,
    feeReceiverAddress,
    reservedColors,
    royalty,
  ];

  const Capsules = await ethers.getContractFactory("CapsulesToken");

  const capsulesToken = (await Capsules.deploy(...args)) as CapsulesToken;

  console.log(
    chalk.green(` ✔ CapsulesToken deployed for network:`),
    process.env.HARDHAT_NETWORK,
    "\n",
    chalk.magenta(capsulesToken.address),
    `tx: ${capsulesToken.deployTransaction.hash}`
  );

  writeFiles(
    "CapsulesToken",
    capsulesToken.address,
    args.map((a) => JSON.stringify(a))
  );

  await capsulesToken.transferOwnership(ownerAddress);

  console.log(
    "Transferred CapsulesToken ownership to " + chalk.bold(ownerAddress)
  );

  return capsulesToken;
};

const main = async () => {
  const deployer = await getDeployer();
  let nonce = await deployer.getTransactionCount();
  const expectedCapsulesTokenAddress = ethers.utils.getContractAddress({
    from: deployer.address,
    nonce: nonce + 2,
  });

  const capsulesTypeface = await deployCapsulesTypeface(
    expectedCapsulesTokenAddress
  );

  const capsulesMetadata = await deployCapsulesMetadata(
    capsulesTypeface.address
  );

  await deployCapsulesToken(
    capsulesTypeface.address,
    capsulesMetadata.address,
  );

  console.log("Done");
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
