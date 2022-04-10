import { TransactionReceipt } from "@ethersproject/abstract-provider";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { parseEther } from "ethers/lib/utils";

import { ITypeface } from "../typechain-types";
import {
  auctionHouseContract,
  capsulesContract,
  deployCapsulesAuctionHouse,
  deployCapsulesToken,
  deployCapsulesTypeface,
  emptyNote,
  formatBytes16,
  indent,
  maxSupply,
  mintedCount,
  mintPrice,
  mintValidCapsules,
  skipToBlockNumber,
  totalSupply,
  wallets,
} from "./utils";

let capsulesTypeface: ITypeface;
export let auctionHouseAddress: string;
export let capsulesAddress: string;

describe("Capsules", async () => {
  before(async () => {
    capsulesTypeface = await deployCapsulesTypeface();

    // Define global capsulesAddress
    capsulesAddress = (await deployCapsulesToken(capsulesTypeface.address))
      .address;

    // Define global auctionHouseAddress
    auctionHouseAddress = (await deployCapsulesAuctionHouse(capsulesAddress))
      .address;
  });

  describe("Deployment", async () => {
    it("Deployment should set owner, fee receiver, and auction house", async () => {
      const { owner, feeReceiver } = await wallets();

      const capsules = capsulesContract();
      const auctionHouse = auctionHouseContract();

      expect(await capsules.owner()).to.equal(owner.address);
      expect(await capsules.auctionHouse()).to.equal(auctionHouseAddress);
      expect(await capsules.creatorFeeReceiver()).to.equal(feeReceiver.address);
      expect(await auctionHouse.capsules()).to.equal(capsulesAddress);
    });
  });

  describe("Initial mint", async () => {
    it.only("Valid mint while paused should revert", async () => {
      const { minter1 } = await wallets();

      await expect(
        capsulesContract(minter1).mint("0x0005ff", emptyNote, {
          value: mintPrice,
        })
      ).to.be.reverted;
    });

    it.only("Should unpause", async () => {
      const { owner } = await wallets();
      const ownerCapsules = capsulesContract(owner);
      await expect(ownerCapsules.unpause())
        .to.emit(ownerCapsules, "Unpaused")
        .withArgs(owner.address);
    });

    it.only("Mint with invalid color should revert", async () => {
      const { minter1 } = await wallets();

      await expect(
        capsulesContract(minter1).mint("0x0000ef", emptyNote, {
          value: mintPrice,
        })
      ).to.be.revertedWith("Invalid color");
    });

    it.only("Mint with low price should revert", async () => {
      const { owner } = await wallets();

      await expect(
        capsulesContract(owner).mint("0x0005ff", emptyNote, {
          value: mintPrice.sub(1),
        })
      ).to.be.revertedWith("Ether value sent is below the mint price");
    });

    it.only("Mint reserved color should revert", async () => {
      const { minter1 } = await wallets();

      await expect(
        capsulesContract(minter1).mint("0x0000ff", emptyNote, {
          value: mintPrice,
        })
      ).to.be.revertedWith("Color reserved for auction");
    });

    it.only("Mint with valid color and note should succeed", async () => {
      const { minter1 } = await wallets();

      const minter1Capsules = capsulesContract(minter1);

      await expect(
        minter1Capsules.mint("0x0005ff", emptyNote, {
          value: mintPrice,
        })
      )
        .to.emit(minter1Capsules, "CapsuleMinted")
        .withArgs(minter1.address, (await totalSupply()).add(1), "0005ff");

      // console.log(
      //   await minter1Capsules.textOf(1, 0),
      //   await minter1Capsules.textOf(1, 7)
      // );
      // console.log(await minter1Capsules.colorOf(1));
      // console.log(await minter1Capsules.tokenURI(1));
    });

    it("Should withdraw half of mint revenue to fee receiver", async () => {
      const { minter1, feeReceiver } = await wallets();

      const minter1Capsules = capsulesContract(minter1);

      const initialFeeReceiverBalance = await feeReceiver.getBalance();

      // Initial withdraw before mint is completed
      await mintValidCapsules(minter1, 1000);

      const capsulesBalance1 = await feeReceiver.provider?.getBalance(
        capsulesAddress
      );

      await expect(minter1Capsules.withdrawCreatorFee())
        .to.emit(minter1Capsules, "WithdrawCreatorFee")
        .withArgs(feeReceiver.address, capsulesBalance1);

      expect(await feeReceiver.getBalance()).to.equal(
        initialFeeReceiverBalance.add(capsulesBalance1!)
      );

      // Withdraw after mint is completed
      await mintValidCapsules(minter1);

      const capsulesBalance2 = await feeReceiver.provider?.getBalance(
        capsulesAddress
      );

      const totalWithdrawn = capsulesBalance1!.add(capsulesBalance2!).div(2);

      await expect(minter1Capsules.withdrawCreatorFee())
        .to.emit(minter1Capsules, "WithdrawCreatorFee")
        .withArgs(feeReceiver.address, totalWithdrawn.sub(capsulesBalance1!));

      expect(await feeReceiver.getBalance()).to.equal(
        initialFeeReceiverBalance.add(totalWithdrawn)
      );

      // Withdraw after mint is completed
      await expect(minter1Capsules.withdrawCreatorFee()).to.be.revertedWith(
        "Cannot withdraw more than 50% of initial mint revenue for creator"
      );
    });

    it("Set text on non-owned capsule should revert", async () => {
      const { minter1, minter2 } = await wallets();

      const minter1Capsules = capsulesContract(minter1);

      const id = 1;

      await minter1Capsules.transferFrom(minter1.address, minter2.address, id);

      await expect(
        minter1Capsules.setText(id, emptyNote, { value: parseEther("0.01") })
      ).to.be.revertedWith("Capsule not owned");
    });

    it("Set text should revert if fee is too low", async () => {
      const { minter1 } = await wallets();

      const minter1Capsules = capsulesContract(minter1);

      const id = 2;

      await expect(
        minter1Capsules.setText(id, emptyNote, { value: parseEther("0.001") })
      ).to.be.revertedWith("Ether value sent is below cost to set text");
    });

    it("Set invalid text should revert", async () => {
      const { minter1 } = await wallets();

      const minter1Capsules = capsulesContract(minter1);

      const id = 2;

      await expect(
        minter1Capsules.setText(
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
          { value: parseEther("0.001") }
        )
      ).to.be.revertedWith("Invalid text");
    });

    it("Set valid text on owned capsule should succeed", async () => {
      const { minter1 } = await wallets();

      const minter1Capsules = capsulesContract(minter1);

      const id = 2;

      const text = [
        formatBytes16("< one! +=-_~"),
        formatBytes16(' "two"? @ # $ %'),
        formatBytes16("  three ` & <>"),
        formatBytes16("   'four'; < "),
        formatBytes16("    five ..."),
        formatBytes16("{   6   } []()|"),
        formatBytes16("> max length 15"),
        formatBytes16("> max length 15"),
      ];

      await expect(
        minter1Capsules.setText(id, text, { value: parseEther("0.01") })
      )
        .to.emit(minter1Capsules, "SetText")
        .withArgs(id, text);
    });
  });

  describe("Delegate actions", async () => {
    it("Non-delegate should not be able to update textEditFee", async () => {
      const { delegate } = await wallets();

      const delegateCapsules = capsulesContract(delegate);

      await expect(
        delegateCapsules.setTextEditFee(parseEther("0.05"))
      ).to.be.revertedWith("Sender is not the Delegate");
    });

    it("Non-delegate should not be able to withdraw", async () => {
      const { delegate } = await wallets();

      const delegateCapsules = capsulesContract(delegate);

      const capsulesBalance = await delegate.provider?.getBalance(
        capsulesAddress
      );
      await expect(
        delegateCapsules.withdraw(capsulesBalance!)
      ).to.be.revertedWith("Sender is not the Delegate");
    });

    it("Set delegate vote should succeed", async () => {
      const { minter1, delegate } = await wallets();

      const minter1Capsules = capsulesContract(minter1);

      let startTime = new Date().valueOf();

      process.stdout.write(`${indent}Set delegate vote for Capsule`);

      // Set >50% vote
      const startId = 2;
      const max = Math.ceil(maxSupply / 2 + 1);

      for (let i = 0; i < max; i++) {
        const id = startId + i;

        await expect(minter1Capsules.setDelegateVote(id, delegate.address))
          .to.emit(minter1Capsules, "SetDelegateVote")
          .withArgs(id, delegate.address);

        process.stdout.cursorTo(30);
        process.stdout.write(`${i}/${max}`);
      }

      process.stdout.cursorTo(0);
      process.stdout.write(
        `${indent}Capsules ${startId}-${max} voted for delegate ${
          delegate.address
        } (${new Date().valueOf() - startTime}ms)`
      );
      process.stdout.write("\n");
    });

    it("Delegate should be able to update textEditFee", async () => {
      const { delegate } = await wallets();

      const delegateCapsules = capsulesContract(delegate);

      const fee = parseEther("0.05");

      await expect(delegateCapsules.setTextEditFee(fee))
        .to.emit(delegateCapsules, "SetTextEditFee")
        .withArgs(fee);

      await expect(await delegateCapsules.textEditFee()).to.equal(
        parseEther("0.05").toString()
      );
    });

    it("Delegate should be able to withdraw", async () => {
      const { delegate } = await wallets();

      const delegateCapsules = capsulesContract(delegate);

      const initialDelegateBalance = await delegate.getBalance();
      const capsulesBalance = await delegate.provider!.getBalance(
        capsulesAddress
      );
      // await expect(tx).to.emit(delegateCapsules, "Withdraw");
      const receipt: TransactionReceipt = await (
        await delegateCapsules.withdraw(capsulesBalance)
      ).wait();

      await expect(await delegate.getBalance()).to.equal(
        initialDelegateBalance
          .add(capsulesBalance)
          .sub(receipt.gasUsed.mul(receipt.effectiveGasPrice))
      );
    });
  });

  describe("Auction house", async () => {
    it("Delegate should be able to unpause", async () => {
      const { minter1, delegate } = await wallets();

      const minter1AuctionHouse = auctionHouseContract(minter1);
      const delegateAuctionHouse = auctionHouseContract(delegate);

      await expect(minter1AuctionHouse.unpause()).to.be.revertedWith(
        "Sender is not the Delegate"
      );
      await delegateAuctionHouse.unpause();

      console.log(
        indent + "First auction:",
        await delegateAuctionHouse.auction()
      );

      await expect(await delegateAuctionHouse.paused()).to.be.false;
    });

    // Minter1 creates bid at reserve price
    it("Create bid should succeed if meets reserve", async () => {
      const { minter1 } = await wallets();

      const minter1AuctionHouse = auctionHouseContract(minter1);

      const { capsuleId } = await minter1AuctionHouse.auction();

      const reservePrice = await minter1AuctionHouse.reservePrice();

      await expect(
        minter1AuctionHouse.createBid(capsuleId, {
          value: reservePrice.sub(1),
        })
      ).to.be.revertedWith("Must send at least reservePrice");

      await minter1AuctionHouse.createBid(capsuleId, { value: reservePrice });
    });

    // Minter2 ups minter1's bid by minBidIncrementPercentage
    // Minter1 is refunded
    it("Create bid should succeed if above min bid increment", async () => {
      const { minter1, minter2 } = await wallets();

      const minter2AuctionHouse = auctionHouseContract(minter2);

      const { capsuleId, amount } = await minter2AuctionHouse.auction();

      const minBidIncrementPercentage =
        await minter2AuctionHouse.minBidIncrementPercentage();

      const value = amount.add(amount.mul(minBidIncrementPercentage).div(100));

      await expect(
        minter2AuctionHouse.createBid(capsuleId, { value: value.sub(1) })
      ).to.be.revertedWith(
        "Must send more than last bid by minBidIncrementPercentage amount"
      );

      const initialMinter1Balance = await minter1.getBalance();

      await minter2AuctionHouse.createBid(capsuleId, { value });

      // Should refund minter1
      await expect(await minter1.getBalance()).eq(
        initialMinter1Balance.add(amount)
      );
    });

    // Minter2 tries to settle before auction ends
    it("Settle auction should fail if called before auction ends", async () => {
      const { minter2 } = await wallets();

      const minter2AuctionHouse = auctionHouseContract(minter2);

      await expect(
        minter2AuctionHouse.settleCurrentAndTryCreateNewAuction()
      ).to.be.revertedWith("Auction hasn't completed");
    });

    // Auction is settled and new auction created
    it("Settle auction should succeed", async () => {
      const { minter1 } = await wallets();

      const capsules = capsulesContract();
      const minter1AuctionHouse = auctionHouseContract(minter1);
      const initialCapsulesBalance = await minter1.provider?.getBalance(
        capsulesAddress
      );

      const { endTime, amount, capsuleId, bidder } =
        await minter1AuctionHouse.auction();

      // Fast forward to end of auction
      await skipToBlockNumber((endTime as BigNumber).toNumber());

      const id = (await mintedCount()).add(1).toNumber();

      // minter2 has winning bid
      // Use minter1 to demonstrate auction can be settled by any caller
      await expect(minter1AuctionHouse.settleCurrentAndTryCreateNewAuction())
        .to.emit(capsules, "CapsuleMinted")
        .withArgs(
          auctionHouseAddress,
          (await mintedCount()).add(1),
          await capsules.colorOf(id)
        );

      console.log(
        indent + "Second auction:",
        await minter1AuctionHouse.auction()
      );

      // Should send auction amount to Capsules contract
      await expect(await minter1.provider?.getBalance(capsulesAddress)).eq(
        initialCapsulesBalance?.add(amount)
      );

      // Winning bidder should own capsule
      await expect(await capsules.ownerOf(capsuleId)).to.equal(bidder);

      // Should start new auction with next capsule
      await expect((await minter1AuctionHouse.auction()).capsuleId).eq(
        capsuleId.add(1)
      );
    });

    it("Capsule without bids should be burned after auction", async () => {
      const { minter1 } = await wallets();

      const minter1AuctionHouse = auctionHouseContract(minter1);

      const { endTime, capsuleId } = await minter1AuctionHouse.auction();

      // Fast forward to end of auction without bid
      await skipToBlockNumber((endTime as BigNumber).toNumber());

      await minter1AuctionHouse.settleCurrentAndTryCreateNewAuction();

      await expect(capsulesContract().ownerOf(capsuleId)).to.be.revertedWith(
        "ERC721: owner query for nonexistent token"
      );
    });

    it("AuctionHouse should stop minting after auction colors", async () => {
      const { minter1 } = await wallets();

      const minter1AuctionHouse = auctionHouseContract(minter1);

      for (
        let i = maxSupply - (await mintedCount()).toNumber();
        i < maxSupply + 1;
        i++
      ) {
        console.log(
          indent + " auction:",
          i,
          await minter1AuctionHouse.auction(),
          (await totalSupply()).toString(),
          (await mintedCount()).toString()
        );

        const { endTime } = await minter1AuctionHouse.auction();

        await minter1AuctionHouse.settleCurrentAndTryCreateNewAuction();

        if (i === maxSupply + 1) {
          // capsuleId should still be that of final capsule
          await expect(
            (await minter1AuctionHouse.auction()).capsuleId.toNumber()
          ).to.equal(maxSupply);
        } else {
          // Fast forward to end of auction and settle
          await skipToBlockNumber((endTime as BigNumber).toNumber());
        }

        await expect((await minter1AuctionHouse.auction()).settled).to.equal(
          true
        );
      }
    });
  });
});
