import { expect } from "chai";
import chalk from "chalk";
import { Contract, Signer } from "ethers";
import * as fs from "fs";
import { ethers } from "hardhat";
import { Typeface, TypefaceExpandable } from "../typechain-types";

import { fontHashes, fonts, fontSources, wallets } from "./utils";

export let typeface: Typeface;

export const typefaceContract = (signer?: Signer) =>
  new Contract(
    typeface.address,
    JSON.parse(
      fs
        .readFileSync(
          "./artifacts/contracts/examples/TestTypefaceExpandable.sol/TestTypefaceExpandable.json"
        )
        .toString()
    ).abi,
    signer ?? ethers.provider
  ) as TypefaceExpandable;

export async function deployTypeface() {
  const { operator, donationAddress } = await wallets();

  const TestTypefaceExpandable = await ethers.getContractFactory(
    "TestTypefaceExpandable"
  );
  const contract = (await TestTypefaceExpandable.deploy(
    fonts,
    fontHashes,
    donationAddress.address,
    operator.address
  )) as Typeface;

  console.log(
    "Deployed TestTypefaceExpandable " + chalk.magenta(contract.address)
  );

  return contract;
}

describe("TestTypefaceExpandable", async () => {
  before(async () => {
    typeface = await deployTypeface();
  });

  it("Should return correct font name", async () => {
    const { rando } = await wallets();

    for (let i = 0; i < fonts.length; i++) {
      expect(await typefaceContract(rando).name()).to.equal("TestTypeface");
    }
  });

  it("Set font hashes should fail for rando", async () => {
    const { rando } = await wallets();

    const font = fonts[0];

    await expect(
      typefaceContract(rando).setSourceHashes([font], [fontHashes[0]])
    ).to.be.revertedWith("TypefaceExpandable: Not operator");
  });

  it("Set font hashes should fail if unequal number of fonts & hashes", async () => {
    const { operator } = await wallets();

    await expect(
      typefaceContract(operator).setSourceHashes(
        [fonts[0]],
        [fontHashes[0], fontHashes[1]]
      )
    ).to.be.revertedWith("Typeface: Unequal number of fonts and hashes");

    await expect(
      typefaceContract(operator).setSourceHashes(
        [fonts[0], fonts[1]],
        [fontHashes[0]]
      )
    ).to.be.revertedWith("Typeface: Unequal number of fonts and hashes");
  });

  it("Change font hash should succeed for operator if no source", async () => {
    const { operator } = await wallets();

    const font = fonts[0];

    await expect(
      typefaceContract(operator).setSourceHashes([font], [fontHashes[0]])
    )
      .to.emit(typeface, "SetSourceHash")
      .withArgs([font.weight, font.style], fontHashes[0]);
  });

  it("Should return false hasSource() for unstored font", async () => {
    const { rando } = await wallets();

    const font = fonts[0];

    return expect(await typefaceContract(rando).hasSource(font)).to.be.false;
  });

  it("Store font source with invalid weight should revert", async () => {
    const { rando } = await wallets();

    const font = fonts[0];

    return expect(
      typefaceContract(rando).setSource(
        {
          ...font,
          weight: 69,
        },
        fontSources[0]
      )
    ).to.be.revertedWith("Typeface: Invalid font");
  });

  it("Store font source with invalid style should revert", async () => {
    const { rando } = await wallets();

    const font = fonts[0];

    return expect(
      typefaceContract(rando).setSource(
        {
          ...font,
          style: "asdf",
        },
        fontSources[0]
      )
    ).to.be.revertedWith("Typeface: Invalid font");
  });

  it("Store font source with invalid source should revert", async () => {
    const { rando } = await wallets();

    const font = fonts[0];

    return expect(
      typefaceContract(rando).setSource(font, fontSources[2])
    ).to.be.revertedWith("Typeface: Invalid font");
  });

  it("Store font source with valid source should succeed", async () => {
    const { rando } = await wallets();

    const font = fonts[0];

    return expect(typefaceContract(rando).setSource(font, fontSources[0]))
      .to.emit(typeface, "SetSource")
      .withArgs([font.weight, font.style]);
  });

  it("Should return correct font hash", async () => {
    const { rando } = await wallets();

    expect(await typefaceContract(rando).sourceHash(fonts[0])).to.equal(
      fontHashes[0]
    );
  });

  it("Should return true hasSource() for stored font", async () => {
    const { rando } = await wallets();

    const font = fonts[0];

    return expect(await typefaceContract(rando).hasSource(font)).to.be.true;
  });

  it("Should return correct font source", async () => {
    const { rando } = await wallets();

    const font = fonts[0];

    expect(await typefaceContract(rando).sourceOf(font)).to.equal(
      "0x" + fontSources[0].toString("hex")
    );
  });

  it("Change font hash should revert if source already exists", async () => {
    const { operator } = await wallets();

    const font = fonts[0];

    await expect(
      typefaceContract(operator).setSourceHashes([font], [fontHashes[0]])
    ).to.be.revertedWith("TypefaceExpandable: Source already exists");
  });

  it("setFontSource should revert if already set", async () => {
    const { rando } = await wallets();

    return expect(
      typefaceContract(rando).setSource(fonts[0], fontSources[0])
    ).to.be.revertedWith("Typeface: Source already exists");
  });

  it("Should return false hasSource() for unset font", async () => {
    const { rando } = await wallets();

    const font = fonts[1];

    return expect(await typefaceContract(rando).hasSource(font)).to.be.false;
  });

  it("setOperator should revert for rando", async () => {
    const { rando } = await wallets();

    return expect(
      typefaceContract(rando).setOperator(rando.address)
    ).to.be.revertedWith("TypefaceExpandable: Not operator");
  });

  it("setOperator should succceed for rando", async () => {
    const { operator, rando } = await wallets();

    await expect(typefaceContract(operator).setOperator(rando.address))
      .to.emit(typeface, "SetOperator")
      .withArgs(rando.address);

    await expect(await typefaceContract(operator).operator()).to.equal(
      rando.address
    );
  });
});
