import chalk from "chalk";
import { BigNumber, Contract, Signer } from "ethers";
import { keccak256 } from "ethers/lib/utils";
import * as fs from "fs";
import { ethers } from "hardhat";

import { fonts } from "../fonts";
import { reservedColors } from "../reservedColors";
import { CapsulesMetadata, CapsulesToken } from "../typechain-types";
import { CapsulesTypeface } from "../typechain-types/CapsulesTypeface";
import { capsulesMetadata, capsulesToken, capsulesTypeface } from "./Capsules";

export const mintPrice = ethers.utils.parseEther("0.01");

export const maxSupply = 7957;

export const totalSupply = async () => await capsulesContract().totalSupply();

export const indent = "      " + chalk.bold("- ");

export const textToBytes4Lines = (text: string[]) => {
  const emptyText = ["", "", "", "", "", "", "", ""];
  return [...emptyText, ...text]
    .filter((_, i) => i < 8)
    .map(stringToBytes4Line);
};

export const stringToBytes4Line = (str?: string) => {
  const arr: string[] = [];
  for (let i = 0; i < 16; i++) {
    let byte = "00000000";
    if (str?.length) {
      byte = Buffer.from(str[i], "utf8").toString("hex").padStart(8, "0");
    }
    arr.push("0x" + byte);
  }
  return arr;
};

export const emptyNote = textToBytes4Lines([]);

export async function skipToBlockNumber(seconds: number) {
  await ethers.provider.send("evm_mine", [seconds]);
}

export async function mintValidUnlockedCapsules(
  signer: Signer,
  count?: number
) {
  let hexes: string[] = [];

  const capsules = capsulesContract(signer);

  const toHex = (num: number) =>
    BigNumber.from(num).toHexString().split("0x")[1];

  for (let r = 0; r <= 255; r += 5) {
    for (let g = 0; g <= 255; g += 5) {
      for (let b = 0; b <= 255; b += 5) {
        if (r === 255 || g === 255 || b === 255) {
          hexes.push("0x" + toHex(r) + toHex(g) + toHex(b));
        }
      }
    }
  }

  const skip = (await capsules.totalSupply()).toNumber();

  const validHexes = hexes
    .filter((h) => !reservedColors.includes(h))
    .slice(skip);

  const _count =
    count !== undefined
      ? Math.min(count, validHexes.length)
      : validHexes.length;

  const startTime = new Date().valueOf();
  process.stdout.write(`${indent}Minting Capsules... 0/${_count}`);

  for (let i = 0; i < _count; i++) {
    await capsules
      .mint(validHexes[i], emptyNote, 400, false, {
        value: mintPrice,
        gasLimit: 30000000,
      })
      .then(() => {
        process.stdout.cursorTo(indent.length + 11);
        process.stdout.write(`${i + 1}/${_count}`);
      });
  }

  process.stdout.cursorTo(indent.length + 21);
  process.stdout.write(`(${new Date().valueOf() - startTime}ms)`);
  process.stdout.write("\n");
}

export async function wallets() {
  const [deployer, owner, feeReceiver, minter1, minter2] =
    await ethers.getSigners();

  return { deployer, owner, feeReceiver, minter1, minter2 };
}

export async function deployCapsulesTypeface(capsulesTokenAddress: string) {
  const _fonts = Object.keys(fonts).map((weight) => ({
    weight: parseInt(weight) as keyof typeof fonts,
    style: "normal",
  }));
  const hashes = Object.values(fonts).map((font) =>
    keccak256(Buffer.from(font))
  );

  console.log("fonts", { _fonts, hashes });

  const CapsulesTypeface = await ethers.getContractFactory("CapsulesTypeface");
  const capsulesTypeface = (await CapsulesTypeface.deploy(
    _fonts,
    hashes,
    capsulesTokenAddress
  )) as CapsulesTypeface;

  const tx = await capsulesTypeface.deployTransaction.wait();
  const price = 50 * 0.000000001;

  console.log(
    indent +
      "Deployed CapsulesTypeface " +
      chalk.magenta(capsulesTypeface.address) +
      " Gas: " +
      tx.gasUsed.toNumber() * price
  );

  return capsulesTypeface;
}

export async function deployCapsulesToken(
  capsulesTypefaceAddress: string,
  capsulesMetadataAddress: string
) {
  const { feeReceiver, owner } = await wallets();
  const Capsules = await ethers.getContractFactory("CapsulesToken");

  const royalty = 50;

  const capsules = (await Capsules.deploy(
    capsulesTypefaceAddress,
    capsulesMetadataAddress,
    feeReceiver.address,
    reservedColors,
    royalty
  )) as CapsulesToken;

  await capsules.transferOwnership(owner.address);

  const tx = await capsules.deployTransaction.wait();
  const price = 50 * 0.000000001;

  console.log(
    indent +
      "Deployed CapsulesToken " +
      chalk.magenta(capsules.address) +
      " Gas: " +
      tx.gasUsed.toNumber() * price
  );

  return capsules;
}

export async function deployCapsulesMetadata(capsulesTypefaceAddress: string) {
  const CapsulesMetadata = await ethers.getContractFactory("CapsulesMetadata");

  const capsulesMetadata = (await CapsulesMetadata.deploy(
    capsulesTypefaceAddress
  )) as CapsulesMetadata;

  const tx = await capsulesMetadata.deployTransaction.wait();
  const price = 50 * 0.000000001;

  console.log(
    indent +
      "Deployed CapsulesMetadata " +
      chalk.magenta(capsulesMetadata.address) +
      " Gas: " +
      tx.gasUsed.toNumber() * price
  );

  return capsulesMetadata;
}

export const capsulesContract = (signer?: Signer) =>
  new Contract(
    capsulesToken.address,
    JSON.parse(
      fs
        .readFileSync(
          "./artifacts/contracts/CapsulesToken.sol/CapsulesToken.json"
        )
        .toString()
    ).abi,
    signer ?? ethers.provider
  ) as CapsulesToken;

export const capsulesMetadataContract = (signer?: Signer) =>
  new Contract(
    capsulesMetadata.address,
    JSON.parse(
      fs
        .readFileSync(
          "./artifacts/contracts/CapsulesMetadata.sol/CapsulesMetadata.json"
        )
        .toString()
    ).abi,
    signer ?? ethers.provider
  ) as CapsulesMetadata;

export const capsulesTypefaceContract = (signer?: Signer) =>
  new Contract(
    capsulesTypeface.address,
    JSON.parse(
      fs
        .readFileSync(
          "./artifacts/contracts/CapsulesTypeface.sol/CapsulesTypeface.json"
        )
        .toString()
    ).abi,
    signer ?? ethers.provider
  ) as CapsulesTypeface;
