import chalk from "chalk";
import { BigNumber, Contract, Signer } from "ethers";
import { keccak256 } from "ethers/lib/utils";
import * as fs from "fs";
import { ethers } from "hardhat";

import { fonts } from "../fonts";
import { reservedColors } from "../reservedColors";
import { CapsulesToken } from "../typechain-types";
import { CapsulesTypeface } from "../typechain-types/CapsulesTypeface";
import { capsulesToken, capsulesTypeface } from "./Capsules";

export const mintPrice = ethers.utils.parseEther("0.02");

export const maxSupply = 7957;

export const totalSupply = async () => await capsulesContract().totalSupply();

export const indent = "      " + chalk.bold("- ");

export const formatBytes16 = (str: string) => {
  let bytes = strToUtf8Bytes(str)
    .map((char) => ethers.utils.hexValue(char).split("0x")[1])
    .join("");
  bytes = bytes.toString().padEnd(32, "00");
  return "0x" + bytes;
};

export const emptyNote = [
  ethers.utils.hexZeroPad("0x0", 16),
  ethers.utils.hexZeroPad("0x0", 16),
  ethers.utils.hexZeroPad("0x0", 16),
  ethers.utils.hexZeroPad("0x0", 16),
  ethers.utils.hexZeroPad("0x0", 16),
  ethers.utils.hexZeroPad("0x0", 16),
  ethers.utils.hexZeroPad("0x0", 16),
  ethers.utils.hexZeroPad("0x0", 16),
];

function strToUtf8Bytes(str: string) {
  const utf8 = [];
  for (let ii = 0; ii < str.length; ii++) {
    let charCode = str.charCodeAt(ii);
    if (charCode < 0x80) utf8.push(charCode);
    else if (charCode < 0x800) {
      utf8.push(0xc0 | (charCode >> 6), 0x80 | (charCode & 0x3f));
    } else if (charCode < 0xd800 || charCode >= 0xe000) {
      utf8.push(
        0xe0 | (charCode >> 12),
        0x80 | ((charCode >> 6) & 0x3f),
        0x80 | (charCode & 0x3f)
      );
    } else {
      ii++;
      // Surrogate pair:
      // UTF-16 encodes 0x10000-0x10FFFF by subtracting 0x10000 and
      // splitting the 20 bits of 0x0-0xFFFFF into two halves
      charCode =
        0x10000 + (((charCode & 0x3ff) << 10) | (str.charCodeAt(ii) & 0x3ff));
      utf8.push(
        0xf0 | (charCode >> 18),
        0x80 | ((charCode >> 12) & 0x3f),
        0x80 | ((charCode >> 6) & 0x3f),
        0x80 | (charCode & 0x3f)
      );
    }
  }
  return utf8;
}

export async function skipToBlockNumber(seconds: number) {
  await ethers.provider.send("evm_mine", [seconds]);
}

export async function mintValidCapsules(signer: Signer, count?: number) {
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
      .mint(validHexes[i], emptyNote, 400, {
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
  const [deployer, owner, feeReceiver, minter1, minter2, friend1] =
    await ethers.getSigners();

  return { deployer, owner, feeReceiver, minter1, minter2, friend1 };
}

export async function deployCapsulesTypeface() {
  const { deployer } = await wallets();

  const _fonts = Object.keys(fonts).map((weight) => ({
    weight: parseInt(weight) as keyof typeof fonts,
    style: "normal",
  }));
  const hashes = Object.values(fonts).map((font) =>
    keccak256(Buffer.from(font))
  );

  console.log("fonts", { _fonts, hashes });

  const nonce = await deployer.getTransactionCount();
  const nonceOffset = 1;
  const expectedCapsulesTokenAddress = ethers.utils.getContractAddress({
    from: deployer.address,
    nonce: nonce + nonceOffset,
  });

  const CapsulesTypeface = await ethers.getContractFactory("CapsulesTypeface");
  const capsulesTypeface = (await CapsulesTypeface.deploy(
    _fonts,
    hashes,
    expectedCapsulesTokenAddress
  )) as CapsulesTypeface;

  const x = await capsulesTypeface.deployTransaction.wait();
  const price = 50 * 0.000000001;
  console.log("deploy", x.gasUsed.toNumber() * price);

  console.log(
    indent +
      "Deployed CapsulesTypeface " +
      chalk.magenta(capsulesTypeface.address)
  );

  return capsulesTypeface;
}

export async function deployCapsulesToken(capsulesTypefaceAddress: string) {
  const { feeReceiver, owner } = await wallets();
  const Capsules = await ethers.getContractFactory("CapsulesToken");

  const royalty = 50;

  const capsules = (await Capsules.deploy(
    capsulesTypefaceAddress,
    feeReceiver.address,
    reservedColors,
    royalty
  )) as CapsulesToken;

  await capsules.transferOwnership(owner.address);

  console.log(
    indent + "Deployed CapsulesToken " + chalk.magenta(capsules.address)
  );

  return capsules;
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
