import { expect } from "chai";
import chalk from "chalk";
import { Contract, Signer } from "ethers";
import * as fs from "fs";
import { ethers } from "hardhat";
import { Typeface } from "../typechain-types";

import { fontHashes, fonts, fontSources, wallets } from "./utils";

export let typeface: Typeface;

export const typefaceContract = (signer?: Signer) =>
  new Contract(
    typeface.address,
    JSON.parse(
      fs
        .readFileSync(
          "./artifacts/contracts/examples/TestTypeface.sol/TestTypeface.json"
        )
        .toString()
    ).abi,
    signer ?? ethers.provider
  ) as Typeface;

export async function deployTypeface() {
  const { donationAddress } = await wallets();

  const TestTypeface = await ethers.getContractFactory("TestTypeface");
  const testTypeface = (await TestTypeface.deploy(
    fonts,
    fontHashes,
    donationAddress.address
  )) as Typeface;

  console.log("Deployed TestTypeface " + chalk.magenta(testTypeface.address));

  return testTypeface;
}

describe("TestTypeface", async () => {
  before(async () => {
    typeface = await deployTypeface();
  });

  it("Should return correct font hashes", async () => {
    const { rando } = await wallets();

    for (let i = 0; i < fonts.length; i++) {
      expect(await typefaceContract(rando).sourceHash(fonts[i])).to.equal(
        fontHashes[i]
      );
    }
  });

  it("Should return correct font name", async () => {
    const { rando } = await wallets();

    for (let i = 0; i < fonts.length; i++) {
      expect(await typefaceContract(rando).name()).to.equal("TestTypeface");
    }
  });

  it("Should return false hasSource() for all fonts", async () => {
    const { rando } = await wallets();

    for (let i = 0; i < fonts.length; i++) {
      const font = fonts[i];

      return expect(await typefaceContract(rando).hasSource(font)).to.be.false;
    }
  });

  it("Store font source with invalid weight should revert", async () => {
    const { rando } = await wallets();

    return expect(
      typefaceContract(rando).setSource(
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
      typefaceContract(rando).setSource(
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
      typefaceContract(rando).setSource(fonts[0], fontSources[2])
    ).to.be.revertedWith("Typeface: Invalid font");
  });

  it("Should store all font sources", async () => {
    const { rando } = await wallets();

    for (let i = 0; i < fonts.length; i++) {
      const font = fonts[i];

      await expect(typefaceContract(rando).setSource(font, fontSources[i]))
        .to.emit(typeface, "SetSource")
        .withArgs([font.weight, font.style]);
    }
  });

  it("Should return true hasSource() for all stored fonts", async () => {
    const { rando } = await wallets();

    for (let i = 0; i < fonts.length; i++) {
      const font = fonts[i];

      return expect(await typefaceContract(rando).hasSource(font)).to.be.true;
    }
  });

  it("setFontSource should revert if already set", async () => {
    const { rando } = await wallets();

    return expect(
      typefaceContract(rando).setSource(fonts[0], fontSources[0])
    ).to.be.revertedWith("Typeface: Source already exists");
  });

  it("Should return correct font sources", async () => {
    const { rando } = await wallets();

    for (let i = 0; i < fonts.length; i++) {
      expect(await typefaceContract(rando).sourceOf(fonts[i])).to.equal(
        "0x" + fontSources[i].toString("hex")
      );
    }
  });

  it("Should return true for supported codepoint", async () => {
    const { rando } = await wallets();

    expect(await typefaceContract(rando).supportsCodePoint("0x000020")).to.be
      .true;
  });

  it("Should return false for unsupported codepoint", async () => {
    const { rando } = await wallets();

    expect(await typefaceContract(rando).supportsCodePoint("0x000000")).to.be
      .false;
  });
});
