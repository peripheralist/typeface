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
  capsulesMetadataContract,
  capsulesTypefaceContract,
  deployCapsulesMetadata,
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
export let capsulesMetadata: CapsulesMetadata;

const gasGwei = 15;
const gasPrice = gasGwei * 0.000000001;

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

    capsulesMetadata = await deployCapsulesMetadata(capsulesTypeface.address);

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

      expect(await capsules.capsulesMetadata()).to.equal(
        capsulesMetadata.address
      );
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
      //       (gas.toNumber() * gasPrice).toString().substring(0, 6) +
      //       " ETH"
      //   );
      // }

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
      const normal400Font = {
        weight: 400,
        style: "normal",
      };
      const normal400Src = Buffer.from(fonts[400]);
      const event = ownerCapsulesTypeface.setFontSrc(
        normal400Font,
        normal400Src
      );
      // const receipt = await (await event).wait();
      // for (const event of receipt.events ?? []) {
      //   if (event.event == "SetSource")
      //     console.log("asdf", event.event, event.args);
      // }
      await expect(event)
        .to.emit(capsulesToken, "MintCapsule")
        .and.to.emit(capsulesTypeface, "SetSource")
        // .withArgs([400, "normal"], normal400Src);

      // Owner should receive Capsule NFT
      expect(await capsulesToken.balanceOf(owner.address)).to.equal(1);
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
      ).to.be.revertedWith("Typeface: font source already exists");
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

    it("Mint pure color should revert", async () => {
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

      const x = (await totalSupply()).add(1);

      const text = textToBytes4Lines([""]);

      await expect(
        minter1Capsules.mint(color, text, fontWeight, false, {
          value: mintPrice,
        })
      ).to.emit(minter1Capsules, "MintCapsule");
      // .withArgs(x, minter1.address, color, text, fontWeight);

      // console.log(
      //   await minter1Capsules.textOf(1, 0),
      //   await minter1Capsules.textOf(1, 7)
      // );
      // console.log('capsuleOf', (await minter1Capsules.capsuleOf(x)).text, (await minter1Capsules.capsuleOf(x)).safeText);
      // console.log("test", await capsulesContract(minter1).test());
      // console.log(
      //   "capsule",
      //   await capsulesMetadataContract(minter1).htmlSafeLine(text[0]),
      //   (await capsulesMetadataContract(minter1).htmlSafeLine(text[0])).length
      // );
      // console.log("capsule", await capsulesContract(minter1).capsuleOf(x));
      // console.log("totalsupply", await minter1Capsules.totalSupply());
      // console.log("svgOf square", await minter1Capsules.svgOf(x, true));
      // console.log('svgOf notsquare',await minter1Capsules.svgOf(1, false));
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
        `ColorAlreadyMinted(${await capsulesToken.tokenIdOfColor(color)})`
      );
    });

    it("Edit non-owned capsule should revert", async () => {
      const { minter1, minter2 } = await wallets();

      const id = 2;

      expect(await capsulesToken.ownerOf(id)).to.not.equal(minter2.address);

      const gas = await capsulesContract(minter1).estimateGas.editCapsule(
        id,
        emptyNote,
        400,
        false
      );

      console.log(
        "Gas to edit capsule",
        "=> " + (gas.toNumber() * gasPrice).toString().substring(0, 6) + " ETH"
      );

      await expect(
        capsulesContract(minter2).editCapsule(id, emptyNote, 400, false)
      ).to.be.revertedWith(
        `NotCapsuleOwner("${await capsulesToken.ownerOf(id)}")`
      );
    });

    it("Edit owned capsule should succeed", async () => {
      const { minter1 } = await wallets();

      const id = 2;

      expect(await capsulesToken.ownerOf(id)).to.equal(minter1.address);

      await capsulesContract(minter1).editCapsule(id, emptyNote, 400, false);
    });

    it("Set invalid font weight should revert", async () => {
      const { minter1 } = await wallets();

      const id = 2;

      await expect(
        capsulesContract(minter1).editCapsule(id, emptyNote, 69, false)
      ).to.be.revertedWith("InvalidFontWeight()");
    });

    it("Set invalid text should revert", async () => {
      const { minter1 } = await wallets();

      const id = 2;

      await expect(
        capsulesContract(minter1).editCapsule(
          id,
          textToBytes4Lines([
            "👽",
            ' "two"? @ # $ %',
            "  three ` & <>",
            "   'four'; < ",
            "    five ...",
            "{   6   } []()|",
            "> max length 15",
            "> max length 15",
          ]),
          400,
          false
        )
      ).to.be.revertedWith("InvalidText()");

      // console.log('svgOf square',id, await capsulesContract(minter1).svgOf(id, true));
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

      // console.log({ initialFeeReceiverBalance, capsulesBalance1 });

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
