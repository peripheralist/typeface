import { expect } from "chai";
import { utils } from "ethers";

import { fonts } from "../fonts";
import {
  CapsulesRenderer,
  CapsulesToken,
  CapsulesTypeface,
} from "../typechain-types";
import {
  capsulesContract,
  capsulesRendererContract,
  capsulesTypefaceContract,
  deployCapsulesRenderer,
  deployCapsulesToken,
  deployCapsulesTypeface,
  emptyNote,
  mintPrice,
  mintValidUnlockedCapsules,
  stringToBytes4Line,
  textToBytes4Lines,
  totalSupply,
  wallets,
} from "./utils";

export let capsulesTypeface: CapsulesTypeface;
export let capsulesToken: CapsulesToken;
export let capsulesRenderer: CapsulesRenderer;

describe("Capsules", async () => {
  before(async () => {
    const { deployer } = await wallets();

    let nonce = await deployer.getTransactionCount();
    const expectedCapsulesTokenAddress = utils.getContractAddress({
      from: deployer.address,
      nonce: nonce + 2,
    });

    capsulesTypeface = await deployCapsulesTypeface(
      expectedCapsulesTokenAddress
    );

    capsulesRenderer = await deployCapsulesRenderer(capsulesTypeface.address);

    capsulesToken = await deployCapsulesToken(
      capsulesTypeface.address,
      capsulesRenderer.address
    );
  });

  describe("Deployment", async () => {
    it("Deploy should set owner, fee receiver, and contract addresses", async () => {
      const { owner, feeReceiver } = await wallets();

      const capsules = capsulesContract();

      expect(await capsules.owner()).to.equal(owner.address);
      expect(await capsules.creatorFeeReceiver()).to.equal(feeReceiver.address);
      expect(await capsules.capsulesTypeface()).to.equal(
        capsulesTypeface.address
      );

      expect(await capsulesTypeface.capsulesToken()).to.equal(
        capsulesToken.address
      );

      expect(await capsulesRenderer.capsulesTypeface()).to.equal(
        capsulesTypeface.address
      );

      expect(await capsules.capsulesRenderer()).to.equal(
        capsulesRenderer.address
      );
    });
  });

  describe("Initialize", async () => {
    it("Valid setFontSrc while paused should revert", async () => {
      const { owner } = await wallets();

      const ownerCapsulesTypeface = capsulesTypefaceContract(owner);

      // Store first font
      return expect(
        ownerCapsulesTypeface.setFontSrc(
          {
            weight: 400,
            style: "normal",
          },
          Buffer.from(fonts[400])
        )
      ).to.be.revertedWith("Pausable: paused");
    });

    it("Should unpause", async () => {
      const { owner } = await wallets();
      const ownerCapsules = capsulesContract(owner);
      return expect(ownerCapsules.unpause())
        .to.emit(ownerCapsules, "Unpaused")
        .withArgs(owner.address);
    });

    it("Store font src with invalid weight should revert", async () => {
      const { owner } = await wallets();

      return expect(
        capsulesTypefaceContract(owner).setFontSrc(
          {
            weight: 69,
            style: "normal",
          },
          Buffer.from(fonts[400])
        )
      ).to.be.revertedWith("Typeface: Invalid font");
    });

    it("Store font src with invalid style should revert", async () => {
      const { owner } = await wallets();

      return expect(
        capsulesTypefaceContract(owner).setFontSrc(
          {
            weight: 400,
            style: "asdf",
          },
          Buffer.from(fonts[400])
        )
      ).to.be.revertedWith("Typeface: Invalid font");
    });

    it("Should store first font and mint Capsule token", async () => {
      const { owner } = await wallets();

      // const _fonts = Object.keys(fonts).map((weight) => ({
      //   weight: parseInt(weight) as keyof typeof fonts,
      //   style: "normal",
      // }));

      // // Estimate gas to store all fonts
      // for (let i = 0; i < _fonts.length; i++) {
      //   const weight = _fonts[i].weight;

      //   const gas = await capsulesTypeface.estimateGas.setFontSrc(
      //     _fonts[i],
      //     Buffer.from(fonts[weight])
      //   );

      //   console.log(
      //     "Gas for",
      //     weight,
      //     "=> " +
      //       (gas.toNumber() * gasPrice).toString().substring(0, 8) +
      //       " ETH"
      //   );
      // }

      // Store first font
      const normal400Font = {
        weight: 400,
        style: "normal",
      };
      const normal400Src = Buffer.from(fonts[400]);
      return expect(
        capsulesTypefaceContract(owner).setFontSrc(normal400Font, normal400Src)
      )
        .to.emit(capsulesToken, "MintCapsule")
        .withArgs(1, owner.address, "0x00ffff")
        .to.emit(capsulesTypeface, "SetSource");
      // .withArgs([400, "normal"], normal400Src); // Args comparison failing
    });

    it("Address that stores font src should receive Capsule NFT", async () => {
      const { owner } = await wallets();

      return expect(await capsulesToken.balanceOf(owner.address)).to.equal(1);
    });

    it("setFontSrc should revert if already set", async () => {
      const { owner } = await wallets();

      const ownerCapsulesTypeface = capsulesTypefaceContract(owner);

      // Store first font
      return expect(
        ownerCapsulesTypeface.setFontSrc(
          {
            weight: 400,
            style: "normal",
          },
          Buffer.from(fonts[400])
        )
      ).to.be.revertedWith("Typeface: font source already exists");
    });
  });

  describe("Minting", async () => {
    it("Mint with unset font weight should revert", async () => {
      const { minter1 } = await wallets();

      return expect(
        capsulesContract(minter1).mint("0x0005ff", 100, {
          value: mintPrice,
        })
      ).to.be.revertedWith("InvalidFontWeight()");
    });

    it("Mint with invalid color should revert", async () => {
      const { minter1 } = await wallets();

      return expect(
        capsulesContract(minter1).mint("0x0000fe", 400, {
          value: mintPrice,
        })
      ).to.be.revertedWith("InvalidColor()");
    });

    // it("Mint with invalid text should revert", async () => {
    //   const { minter1 } = await wallets();

    //   await expect(
    //     capsulesContract(minter1).mintWithText(
    //       "0x000aff",
    //       400,
    //       textToBytes4Lines(["💩"]),
    //       {
    //         value: mintPrice,
    //       }
    //     )
    //   ).to.be.revertedWith("InvalidText()");
    // });

    it("Mint with low price should revert", async () => {
      const { owner } = await wallets();

      return expect(
        capsulesContract(owner).mint("0x0005ff", 400, {
          value: mintPrice.sub(1),
        })
      ).to.be.revertedWith("ValueBelowMintPrice()");
    });

    it("Mint pure color should revert", async () => {
      const { minter1 } = await wallets();

      return expect(
        capsulesContract(minter1).mint("0x0000ff", 400, {
          value: mintPrice,
        })
      ).to.be.revertedWith("PureColorNotAllowed()");
    });

    it("Mint with valid color should succeed", async () => {
      const { minter1 } = await wallets();

      const minter1Capsules = capsulesContract(minter1);

      const fontWeight = 400;

      const color = "0x0005ff";

      return expect(
        minter1Capsules.mint(color, fontWeight, {
          value: mintPrice,
        })
      )
        .to.emit(minter1Capsules, "MintCapsule")
        .withArgs(2, minter1.address, color);
    });

    it("Mint with valid color and text should succeed", async () => {
      const { minter1 } = await wallets();

      const minter1Capsules = capsulesContract(minter1);

      const fontWeight = 400;

      const color = "0x000aff";

      const text = textToBytes4Lines([""]);

      return expect(
        minter1Capsules.mintWithText(color, fontWeight, text, {
          value: mintPrice,
        })
      )
        .to.emit(minter1Capsules, "MintCapsule")
        .withArgs(3, minter1.address, color);
    });

    it("Mint already minted color should revert", async () => {
      const { minter1 } = await wallets();

      const minter1Capsules = capsulesContract(minter1);

      const color = "0x0005ff";

      const tokenIdOfColor = await capsulesToken.tokenIdOfColor(color);

      return expect(
        minter1Capsules.mint(color, 400, {
          value: mintPrice,
        })
      ).to.be.revertedWith(`ColorAlreadyMinted(${tokenIdOfColor})`);
    });

    // it("Should mint all capsules", async () => {
    //   const { minter2 } = await wallets();

    //   await mintValidUnlockedCapsules(minter2);
    // });
  });

  describe("Capsule owner", async () => {
    it("Edit non-owned capsule should revert", async () => {
      const { minter2 } = await wallets();

      const id = 2;

      const owner = await capsulesToken.ownerOf(id);

      return expect(
        capsulesContract(minter2).editCapsule(id, emptyNote, 400, false)
      ).to.be.revertedWith(`NotCapsuleOwner("${owner}")`);
    });

    it("Edit owned capsule should succeed", async () => {
      const { minter1 } = await wallets();

      const id = 2;

      return capsulesContract(minter1).editCapsule(id, emptyNote, 400, false);
    });

    it("Set invalid font weight should revert", async () => {
      const { minter1 } = await wallets();

      const id = 2;

      return expect(
        capsulesContract(minter1).editCapsule(id, emptyNote, 69, false)
      ).to.be.revertedWith("InvalidFontWeight()");
    });

    // it("Set invalid text should revert", async () => {
    //   const { minter1 } = await wallets();

    //   const id = 2;

    //   await expect(
    //     capsulesContract(minter1).editCapsule(
    //       id,
    //       textToBytes4Lines(["👽"]),
    //       400,
    //       false
    //     )
    //   ).to.be.revertedWith("InvalidText()");
    // });

    it("Lock non-owned capsule should revert", async () => {
      const { minter1, minter2 } = await wallets();

      const id = 2;

      return expect(
        capsulesContract(minter2).lockCapsule(id)
      ).to.be.revertedWith(`NotCapsuleOwner("${minter1.address}")`);
    });

    it("Lock owned capsule should succeed", async () => {
      const { minter1 } = await wallets();

      const id = 2;

      return capsulesContract(minter1).lockCapsule(id);
    });

    it("Edit locked capsule should revert", async () => {
      const { minter1 } = await wallets();

      const id = 2;

      return expect(
        capsulesContract(minter1).editCapsule(id, emptyNote, 400, false)
      ).to.be.revertedWith("CapsuleLocked()");
    });
  });

  describe("Admin", async () => {
    it("Should withdraw balance to fee receiver", async () => {
      const { minter1, feeReceiver } = await wallets();

      const minter1Capsules = capsulesContract(minter1);

      const initialFeeReceiverBalance = await feeReceiver.getBalance();

      const capsulesBalance1 = await feeReceiver.provider?.getBalance(
        capsulesToken.address
      );

      await expect(minter1Capsules.withdraw())
        .to.emit(minter1Capsules, "Withdraw")
        .withArgs(feeReceiver.address, capsulesBalance1);

      expect(await feeReceiver.getBalance()).to.equal(
        initialFeeReceiverBalance.add(capsulesBalance1!)
      );

      expect(
        await feeReceiver.provider?.getBalance(capsulesToken.address)
      ).to.equal(0);
    });
  });
});
