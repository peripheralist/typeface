import { expect } from "chai";
import chalk from "chalk";
import { Contract, Signer } from "ethers";
import * as fs from "fs";
import { ethers } from "hardhat";
import { UTF16Typeface } from "../typechain-types";

import { fontHashes, fonts, fontSources, wallets } from "./utils";

export let utf16Typeface: UTF16Typeface;

export const utf16TypefaceContract = (signer?: Signer) =>
  new Contract(
    utf16Typeface.address,
    JSON.parse(
      fs
        .readFileSync(
          "./artifacts/contracts/examples/UTF16Typeface.sol/UTF16Typeface.json"
        )
        .toString()
    ).abi,
    signer ?? ethers.provider
  ) as UTF16Typeface;

export async function deployUTF16Typeface() {
  const UTF16Typeface = await ethers.getContractFactory("UTF16Typeface");
  const utf16Typeface = (await UTF16Typeface.deploy(
    fonts,
    fontHashes
  )) as UTF16Typeface;

  console.log("Deployed UTF16Typeface " + chalk.magenta(utf16Typeface.address));

  return utf16Typeface;
}

describe("UTF16Typeface", async () => {
  before(async () => {
    utf16Typeface = await deployUTF16Typeface();
  });

  it("Should return correct font hashes", async () => {
    const { rando } = await wallets();

    for (let i = 0; i < fonts.length; i++) {
      expect(await utf16TypefaceContract(rando).sourceHash(fonts[i])).to.equal(
        fontHashes[i]
      );
    }
  });

  it("Store font source with invalid weight should revert", async () => {
    const { rando } = await wallets();

    return expect(
      utf16TypefaceContract(rando).setSource(
        {
          ...fonts[0],
          weight: 69,
        },
        fontSources[0]
      )
    ).to.be.revertedWith("Typeface: Invalid font");
  });

  it("Store font source with invalid style should revert", async () => {
    const { rando } = await wallets();

    return expect(
      utf16TypefaceContract(rando).setSource(
        {
          ...fonts[0],
          style: "asdf",
        },
        fontSources[0]
      )
    ).to.be.revertedWith("Typeface: Invalid font");
  });

  it("Store font source with invalid source should revert", async () => {
    const { rando } = await wallets();

    return expect(
      utf16TypefaceContract(rando).setSource(fonts[0], fontSources[2])
    ).to.be.revertedWith("Typeface: Invalid font");
  });

  it("Should store all font sources", async () => {
    const { rando } = await wallets();

    for (let i = 0; i < fonts.length; i++) {
      const font = fonts[i];

      await expect(utf16TypefaceContract(rando).setSource(font, fontSources[i]))
        .to.emit(utf16Typeface, "SetSource")
        .withArgs([font.weight, font.style]);
    }
  });

  it("setFontSource should revert if already set", async () => {
    const { rando } = await wallets();

    return expect(
      utf16TypefaceContract(rando).setSource(fonts[0], fontSources[0])
    ).to.be.revertedWith("Typeface: font source already exists");
  });

  it("Should return correct font sources", async () => {
    const { rando } = await wallets();

    for (let i = 0; i < fonts.length; i++) {
      expect(await utf16TypefaceContract(rando).sourceOf(fonts[i])).to.equal(
        "0x" + fontSources[i].toString("hex")
      );
    }
  });

  it("Should return true for supported byte", async () => {
    const { rando } = await wallets();

    expect(await utf16TypefaceContract(rando).isSupportedByte("0x20")).to.be
      .true;
  });

  it("Should return false for unsupported byte", async () => {
    const { rando } = await wallets();

    expect(await utf16TypefaceContract(rando).isSupportedByte("0x01")).to.be
      .false;
  });

  it("Should return true for supported bytes4", async () => {
    const { rando } = await wallets();

    expect(await utf16TypefaceContract(rando).isSupportedBytes4("0x00E289A5"))
      .to.be.true;
  });

  it("Should return false for unsupported bytes4", async () => {
    const { rando } = await wallets();

    expect(await utf16TypefaceContract(rando).isSupportedBytes4("0x00000001"))
      .to.be.false;
  });
});
