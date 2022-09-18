import { keccak256 } from "ethers/lib/utils";
import { ethers } from "hardhat";

import { FONTS } from "../fonts";

export async function wallets() {
  const [deployer, donationAddress, operator, rando] =
    await ethers.getSigners();

  return { deployer, donationAddress, operator, rando };
}

export type Font = {
  weight: keyof typeof FONTS[keyof typeof FONTS];
  style: keyof typeof FONTS;
};

export const fonts: Font[] = [
  {
    style: "normal",
    weight: 400,
  },
  {
    style: "normal",
    weight: 600,
  },
  {
    style: "italic",
    weight: 400,
  },
  {
    style: "italic",
    weight: 600,
  },
];

export const fontSources = fonts.map((f) =>
  Buffer.from(FONTS[f.style][f.weight])
);

export const fontHashes = fontSources.map((f) => keccak256(f));
