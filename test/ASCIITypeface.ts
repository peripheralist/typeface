import { expect } from "chai";
import chalk from "chalk";
import { Contract, Signer } from "ethers";
import * as fs from "fs";
import { ethers } from "hardhat";
import { ASCIITypeface } from "../typechain-types";

import { fontHashes, fonts, fontSources, wallets } from "./utils";

export let asciiTypeface: ASCIITypeface;

export const asciiTypefaceContract = (signer?: Signer) =>
  new Contract(
    asciiTypeface.address,
    JSON.parse(
      fs
        .readFileSync(
          "./artifacts/contracts/examples/ASCIITypeface.sol/ASCIITypeface.json"
        )
        .toString()
    ).abi,
    signer ?? ethers.provider
  ) as ASCIITypeface;

export async function deployASCIITypeface() {
  const ASCIITypeface = await ethers.getContractFactory("ASCIITypeface");
  const asciiTypeface = (await ASCIITypeface.deploy(
    fonts,
    fontHashes
  )) as ASCIITypeface;

  console.log("Deployed ASCIITypeface " + chalk.magenta(asciiTypeface.address));

  return asciiTypeface;
}

describe("ASCIITypeface", async () => {
  before(async () => {
    asciiTypeface = await deployASCIITypeface();
  });

  it("Should return correct font hashes", async () => {
    const { rando } = await wallets();

    for (let i = 0; i < fonts.length; i++) {
      expect(await asciiTypefaceContract(rando).sourceHash(fonts[i])).to.equal(
        fontHashes[i]
      );
    }
  });

  it("Store font source with invalid weight should revert", async () => {
    const { rando } = await wallets();

    return expect(
      asciiTypefaceContract(rando).setSource(
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
      asciiTypefaceContract(rando).setSource(
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
      asciiTypefaceContract(rando).setSource(fonts[0], fontSources[2])
    ).to.be.revertedWith("Typeface: Invalid font");
  });

  it("Should store all font sources", async () => {
    const { rando } = await wallets();

    for (let i = 0; i < fonts.length; i++) {
      const font = fonts[i];

      const tx = asciiTypefaceContract(rando).setSource(font, fontSources[i]);

      await expect(tx).to.emit(asciiTypeface, "BeforeSetSource");
      await expect(tx)
        .to.emit(asciiTypeface, "SetSource")
        .withArgs([font.weight, font.style]);
      await expect(tx).to.emit(asciiTypeface, "AfterSetSource");
    }
  });

  it("setFontSource should revert if already set", async () => {
    const { rando } = await wallets();

    return expect(
      asciiTypefaceContract(rando).setSource(fonts[0], fontSources[0])
    ).to.be.revertedWith("Typeface: font source already exists");
  });

  it("Should return correct font sources", async () => {
    const { rando } = await wallets();

    for (let i = 0; i < fonts.length; i++) {
      expect(await asciiTypefaceContract(rando).sourceOf(fonts[i])).to.equal(
        "0x" + fontSources[i].toString("hex")
      );
    }
  });

  it("Should return true for supported byte", async () => {
    const { rando } = await wallets();

    expect(await asciiTypefaceContract(rando).isSupportedByte("0x20")).to.be
      .true;
  });

  it("Should return false for unsupported byte", async () => {
    const { rando } = await wallets();

    expect(await asciiTypefaceContract(rando).isSupportedByte("0x01")).to.be
      .false;
  });

  it("Should return true for supported bytes4", async () => {
    const { rando } = await wallets();

    expect(await asciiTypefaceContract(rando).isSupportedBytes4("0x00000020"))
      .to.be.true;
  });

  it("Should return false for unsupported bytes4", async () => {
    const { rando } = await wallets();

    expect(await asciiTypefaceContract(rando).isSupportedBytes4("0x00000001"))
      .to.be.false;
  });
});
