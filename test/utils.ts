import chalk from "chalk";
import { BigNumber, constants, Contract, Signer } from "ethers";
import { keccak256, parseEther } from "ethers/lib/utils";
import * as fs from "fs";
import { ethers } from "hardhat";

import { CapsulesToken, CapsulesTypeface, Typeface } from "../typechain-types";
import { CapsulesAuctionHouse } from "../typechain-types/CapsulesAuctionHouse";
import { auctionHouseAddress, capsulesAddress } from "./Capsules";
import { fonts } from "./fonts";
import { ITypeface } from "../typechain-types/ITypeface";

export const mintPrice = ethers.utils.parseEther("0.1");
export const auctionColors = [
  "0xff0000",
  "0x00ff00",
  "0x0000ff",
  "0x00ffff",
  "0xffff00",
  "0xff00ff",
  "0xffffff",
];
export const initialSupply = 7950;
export const maxSupply = initialSupply + auctionColors.length;

export const totalSupply = async () => await capsulesContract().totalSupply();
export const mintedCount = async () => await capsulesContract().mintedCount();

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
    .filter((h) => !auctionColors.includes(h))
    .slice(skip);

  const _count =
    count !== undefined
      ? Math.min(count, validHexes.length)
      : validHexes.length;

  const startTime = new Date().valueOf();
  process.stdout.write(`${indent}Minting Capsules... 0/${_count}`);

  for (let i = 0; i < _count; i++) {
    await capsules
      .mint(validHexes[i], emptyNote, {
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
  const [deployer, owner, feeReceiver, minter1, minter2, delegate] =
    await ethers.getSigners();

  return { deployer, owner, feeReceiver, minter1, minter2, delegate };
}

export async function deployCapsulesTypeface() {
  const CapsulesTypeface = await ethers.getContractFactory("CapsulesTypeface");

  const _fonts = Object.keys(fonts).map((weight) => ({
    weight: parseInt(weight) as keyof typeof fonts,
    style: "normal",
  }));
  const hashes = Object.values(fonts).map((font) =>
    keccak256(Buffer.from(font))
  );

  console.log("fonts", _fonts, hashes);

  const capsulesTypeface = (await CapsulesTypeface.deploy(_fonts, hashes, {
    gasLimit: 30000000,
  })) as ITypeface;

  const x = await capsulesTypeface.deployTransaction.wait();
  const price = 50 * 0.000000001;
  console.log("deploy", x.gasUsed.toNumber() * price);

  for (let i = 0; i < _fonts.length; i++) {
    const weight = _fonts[i].weight;

    console.log(
      weight,
      (
        await (
          await capsulesTypeface.setFontSrc(
            _fonts[i],
            Buffer.from(fonts[weight])
          )
        ).wait()
      ).gasUsed.toNumber() * price
    );
  }

  console.log(
    indent +
      "Deployed CapsulesTypeface " +
      chalk.magenta(capsulesTypeface.address)
  );

  return capsulesTypeface;
}

export async function deployCapsulesToken(capsulesTypefaceAddress: string) {
  const { deployer, feeReceiver, owner } = await wallets();
  const Capsules = await ethers.getContractFactory("CapsulesToken");

  const nonce = await deployer.getTransactionCount();
  const AUCTION_HOUSE_NONCE_OFFSET = 2;

  const expectedAuctionHouseAddress = ethers.utils.getContractAddress({
    from: deployer.address,
    nonce: nonce + AUCTION_HOUSE_NONCE_OFFSET,
  });

  const capsules = (await Capsules.deploy(
    parseEther("0.01").toHexString(),
    capsulesTypefaceAddress,
    expectedAuctionHouseAddress,
    feeReceiver.address,
    auctionColors
  )) as CapsulesToken;

  await capsules.transferOwnership(owner.address);

  console.log(
    indent + "Deployed CapsulesToken " + chalk.magenta(capsules.address)
  );

  return capsules;
}

export async function deployCapsulesAuctionHouse(capsulesAddress: string) {
  const AuctionHouse = await ethers.getContractFactory("CapsulesAuctionHouse");

  const auctionHouse = (await AuctionHouse.deploy(
    capsulesAddress,
    constants.AddressZero, // Does not test WETH functionality
    180, // 3 min
    parseEther("0.1"),
    5,
    60 * 60 * 24
  )) as CapsulesAuctionHouse;

  console.log(
    indent +
      "Deployed CapsulesAuctionHouse " +
      chalk.magenta(auctionHouse.address)
  );

  return auctionHouse;
}

export const capsulesContract = (signer?: Signer) =>
  new Contract(
    capsulesAddress,
    JSON.parse(
      fs
        .readFileSync(
          "./artifacts/contracts/CapsulesToken.sol/CapsulesToken.json"
        )
        .toString()
    ).abi,
    signer ?? ethers.provider
  ) as CapsulesToken;

export const auctionHouseContract = (signer?: Signer) =>
  new Contract(
    auctionHouseAddress,
    JSON.parse(
      fs
        .readFileSync(
          "./artifacts/contracts/CapsulesAuctionHouse.sol/CapsulesAuctionHouse.json"
        )
        .toString()
    ).abi,
    signer ?? ethers.provider
  ) as CapsulesAuctionHouse;
