import { expect } from "chai";
import { utils } from "ethers";

import { fonts } from "../fonts";
import {
  CapsulesMetadata,
  CapsulesToken,
  CapsulesTypeface,
} from "../typechain-types";
import {
  capsulesContract,
  capsulesTypefaceContract,
  deployCapsulesMetadata,
  deployCapsulesToken,
  deployCapsulesTypeface,
  emptyNote,
  formatBytes16,
  mintPrice,
  mintValidUnlockedCapsules,
  totalSupply,
  wallets,
} from "./utils";

export let capsulesTypeface: CapsulesTypeface;
export let capsulesToken: CapsulesToken;
export let capsulesMetadata: CapsulesMetadata;

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

    capsulesMetadata = await deployCapsulesMetadata(
      capsulesTypeface.address
    );

    capsulesToken = await deployCapsulesToken(
      capsulesTypeface.address,
      capsulesMetadata.address
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

      expect(await capsulesMetadata.capsulesTypeface()).to.equal(
        capsulesTypeface.address
      );

      expect(await capsules.capsulesMetadata()).to.equal(capsulesMetadata.address)
    });
  });

  describe("Initialize", async () => {
    it("Valid setFontSrc while paused should revert", async () => {
      const { owner } = await wallets();

      const ownerCapsulesTypeface = capsulesTypefaceContract(owner);

      // Store first font
      await expect(
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
      await expect(ownerCapsules.unpause())
        .to.emit(ownerCapsules, "Unpaused")
        .withArgs(owner.address);
    });

    it("Should store first font and mint Capsule token", async () => {
      const { owner } = await wallets();

      const ownerCapsulesTypeface = capsulesTypefaceContract(owner);

      const _fonts = Object.keys(fonts).map((weight) => ({
        weight: parseInt(weight) as keyof typeof fonts,
        style: "normal",
      }));

      const gasPrice = 50 * 0.000000001;

      // Estimate gas to store all fonts
      for (let i = 0; i < _fonts.length; i++) {
        const weight = _fonts[i].weight;

        const gas = await capsulesTypeface.estimateGas.setFontSrc(
          _fonts[i],
          Buffer.from(fonts[weight])
        );

        console.log(
          "Gas for",
          weight,
          "=> " +
            (gas.toNumber() * gasPrice).toString().substring(0, 6) +
            " ETH"
        );
      }

      await expect(
        ownerCapsulesTypeface.setFontSrc(
          {
            weight: 69,
            style: "normal",
          },
          Buffer.from(fonts[400])
        )
      ).to.be.revertedWith("Typeface: Invalid font");

      await expect(
        ownerCapsulesTypeface.setFontSrc(
          {
            weight: 400,
            style: "asdf",
          },
          Buffer.from(fonts[400])
        )
      ).to.be.revertedWith("Typeface: Invalid font");

      // Store first font
      await expect(
        ownerCapsulesTypeface.setFontSrc(
          {
            weight: 400,
            style: "normal",
          },
          Buffer.from(fonts[400])
        )
      )
        .to.emit(capsulesToken, "MintCapsule")
        .and.to.emit(capsulesTypeface, "SetFontSrc");

      // Owner should receive Capsule NFT
      await expect(await capsulesToken.balanceOf(owner.address)).to.equal(1);
    });

    it("setFontSrc should revert if already set", async () => {
      const { owner } = await wallets();

      const ownerCapsulesTypeface = capsulesTypefaceContract(owner);

      // Store first font
      await expect(
        ownerCapsulesTypeface.setFontSrc(
          {
            weight: 400,
            style: "normal",
          },
          Buffer.from(fonts[400])
        )
      ).to.be.revertedWith("Typeface: font src already exists");
    });
  });

  describe("Claiming", async () => {
    it("Should set claim list", async () => {
      const { owner, friend1 } = await wallets();

      await capsulesContract(owner).setClaimable([friend1.address], [1]);

      expect(await capsulesContract().claimCount(friend1.address)).to.equal(1);
    });

    it("Claim should fail for non-friend", async () => {
      const { minter1 } = await wallets();

      await expect(
        capsulesContract(minter1).claim("0xff0005", emptyNote, 400, false)
      ).to.be.revertedWith("NoClaimableTokens()");
    });

    it("Claim should succeed for non-friend", async () => {
      const { friend1 } = await wallets();

      await capsulesContract(friend1).claim("0xff0005", emptyNote, 400, false);
    });

    it("Claim should fail if friend already claimed all claimable tokens", async () => {
      const { friend1 } = await wallets();

      await expect(
        capsulesContract(friend1).claim("0xff00a0", emptyNote, 400, false)
      ).to.be.revertedWith("NoClaimableTokens()");
    });
  });

  describe("Minting", async () => {
    it("Mint with unset font weight should revert", async () => {
      const { minter1 } = await wallets();

      await expect(
        capsulesContract(minter1).mint("0x0005ff", emptyNote, 100, false, {
          value: mintPrice,
        })
      ).to.be.revertedWith("InvalidFontWeight()");
    });

    it("Mint with invalid color should revert", async () => {
      const { minter1 } = await wallets();

      await expect(
        capsulesContract(minter1).mint("0x0000fe", emptyNote, 400, false, {
          value: mintPrice,
        })
      ).to.be.revertedWith("InvalidColor()");
    });

    it("Mint with low price should revert", async () => {
      const { owner } = await wallets();

      await expect(
        capsulesContract(owner).mint("0x0005ff", emptyNote, 400, false, {
          value: mintPrice.sub(1),
        })
      ).to.be.revertedWith("ValueBelowMintPrice()");
    });

    it("Mint reserved color should revert", async () => {
      const { minter1 } = await wallets();

      await expect(
        capsulesContract(minter1).mint("0x0000ff", emptyNote, 400, false, {
          value: mintPrice,
        })
      ).to.be.revertedWith("PureColorNotAllowed()");
    });

    it("Mint with valid color and note should succeed", async () => {
      const { minter1 } = await wallets();

      const minter1Capsules = capsulesContract(minter1);

      const fontWeight = 400;

      const color = "0x0005ff";

      await expect(
        minter1Capsules.mint(color, emptyNote, fontWeight, false, {
          value: mintPrice,
        })
      )
        .to.emit(minter1Capsules, "MintCapsule")
        .withArgs(
          (await totalSupply()).add(1),
          minter1.address,
          color,
          emptyNote,
          fontWeight
        );

      // console.log(
      //   await minter1Capsules.textOf(1, 0),
      //   await minter1Capsules.textOf(1, 7)
      // );
      // console.log('capsuleFor',await minter1Capsules.capsuleFor(1));
      console.log('svgOf square',await minter1Capsules.svgOf(1, true));
      console.log('svgOf notsquare',await minter1Capsules.svgOf(1, false));
    });

    it("Mint already minted color should revert", async () => {
      const { minter1 } = await wallets();

      const minter1Capsules = capsulesContract(minter1);

      const color = "0x0005ff";

      await expect(
        minter1Capsules.mint(color, emptyNote, 400, false, {
          value: mintPrice,
        })
      ).to.be.revertedWith(
        `ColorAlreadyMinted(${await capsulesToken.capsuleForColor(color)})`
      );
    });

    it("Edit non-owned capsule should revert", async () => {
      const { minter2 } = await wallets();

      const id = 3;

      expect(await capsulesToken.ownerOf(id)).to.not.equal(minter2.address);

      await expect(
        capsulesContract(minter2).editCapsule(id, emptyNote, 400, false)
      ).to.be.revertedWith(
        `NotCapsuleOwner("${await capsulesToken.ownerOf(id)}")`
      );
    });

    it("Edit owned capsule should succeed", async () => {
      const { minter1 } = await wallets();

      const id = 3;

      expect(await capsulesToken.ownerOf(id)).to.equal(minter1.address);

      await capsulesContract(minter1).editCapsule(id, emptyNote, 400, false);
    });

    it("Set invalid font weight should revert", async () => {
      const { minter1 } = await wallets();

      const id = 3;

      await expect(
        capsulesContract(minter1).editCapsule(id, emptyNote, 69, false)
      ).to.be.revertedWith("InvalidFontWeight()");
    });

    it("Set invalid text should revert", async () => {
      const { minter1 } = await wallets();

      const id = 3;

      await expect(
        capsulesContract(minter1).editCapsule(
          id,
          [
            formatBytes16("👽"),
            formatBytes16(' "two"? @ # $ %'),
            formatBytes16("  three ` & <>"),
            formatBytes16("   'four'; < "),
            formatBytes16("    five ..."),
            formatBytes16("{   6   } []()|"),
            formatBytes16("> max length 15"),
            formatBytes16("> max length 15"),
          ],
          400,
          false
        )
      ).to.be.revertedWith("InvalidText()");
    });

    // it("Should mint all capsules", async () => {
    //   const { minter2 } = await wallets();

    //   await mintValidUnlockedCapsules(minter2);
    // });

    it("Should withdraw balance to fee receiver", async () => {
      const { minter1, feeReceiver } = await wallets();

      const minter1Capsules = capsulesContract(minter1);

      const initialFeeReceiverBalance = await feeReceiver.getBalance();

      const capsulesBalance1 = await feeReceiver.provider?.getBalance(
        capsulesToken.address
      );

      console.log({ initialFeeReceiverBalance, capsulesBalance1 });

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
