const { expect } = require("chai");
const { ethers } = require("hardhat");

const mintPrice = ethers.utils.parseEther("0.1");
const defaultMaxSupply = 10;

const formatBytes15 = (str) => {
  let bytes = strToUtf8Bytes(str)
    .map((char) => ethers.utils.hexValue(char).split("0x")[1])
    .join("");
  bytes = bytes.toString().padEnd(30, "20");
  return "0x" + bytes;
};

const defaultNote = [
  ethers.utils.hexZeroPad("0x0", 15),
  ethers.utils.hexZeroPad("0x0", 15),
  ethers.utils.hexZeroPad("0x0", 15),
  ethers.utils.hexZeroPad("0x0", 15),
  ethers.utils.hexZeroPad("0x0", 15),
  ethers.utils.hexZeroPad("0x0", 15),
  ethers.utils.hexZeroPad("0x0", 15),
];

function strToUtf8Bytes(str) {
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

async function mintCapsules(capsules, count) {
  let promises = [];

  for (let i = 0; i < count; i++) {
    promises.push(
      capsules.mint(defaultNote, {
        value: mintPrice,
      })
    );
  }

  await Promise.all(promises);
}

let capsuleTypeface;

async function deployCapsuleTypeface() {
  const CapsuleTypeface = await ethers.getContractFactory("CapsuleTypeface");
  capsuleTypeface = await CapsuleTypeface.deploy();
}

async function deploy(supply = defaultMaxSupply) {
  const [owner] = await ethers.getSigners();

  const Capsules = await ethers.getContractFactory("Capsules");

  const capsules = await Capsules.deploy(
    owner.address,
    supply,
    capsuleTypeface.address
  );

  return { capsules, owner };
}

before(deployCapsuleTypeface);

describe("Capsules contract", function () {
  it("Deployment should set owner to address argument", async function () {
    const { capsules, owner } = await deploy();

    expect(await capsules.owner()).to.equal(owner.address);
  });

  it("Mint should revert if sale is inactive", async function () {
    const { capsules } = await deploy();

    await expect(
      capsules.mint(defaultNote, {
        value: mintPrice,
      })
    ).to.be.revertedWith("Sale is inactive");
  });

  it("Mint should revert if price is too low", async function () {
    const { capsules } = await deploy();

    await capsules.setSaleIsActive(true);

    await expect(capsules.mint(defaultNote), { value: 0 }).to.be.revertedWith(
      "Ether value sent is below the mint price"
    );
  });

  it("Mint should revert if max supply is reached", async function () {
    const { capsules } = await deploy();

    await capsules.setSaleIsActive(true);

    await mintCapsules(capsules, defaultMaxSupply);

    await expect(
      capsules.mint(defaultNote, {
        value: mintPrice,
      })
    ).to.be.revertedWith("All Capsules have been minted");
  });

  it("Withdraw to zero address should revert", async function () {
    const { capsules, owner } = await deploy();

    await capsules.setSaleIsActive(true);

    await mintCapsules(capsules, defaultMaxSupply);

    const balance = owner.provider.getBalance(capsules.address);

    await expect(
      capsules.withdrawToRecipient(ethers.constants.AddressZero, balance)
    ).to.be.revertedWith("Cannot withdraw to zero address");
  });

  it("Withdraw to non-recipient address should revert", async function () {
    const { capsules, owner } = await deploy();

    await capsules.setSaleIsActive(true);

    await mintCapsules(capsules, defaultMaxSupply);

    const balance = owner.provider.getBalance(capsules.address);

    await expect(
      capsules.withdrawToRecipient(
        "0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8",
        balance
      )
    ).to.be.revertedWith("Recipient is not majority");
  });

  it("Withdraw to recipient address should succeed", async function () {
    const { capsules, owner } = await deploy();

    await capsules.setSaleIsActive(true);

    await mintCapsules(capsules, defaultMaxSupply);

    const balance = owner.provider.getBalance(capsules.address);

    for (let i = 0; i < 6; i++) {
      await capsules.setRecipientVote(
        i + 1,
        "0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8"
      );
    }

    await capsules.withdrawToRecipient(
      "0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8",
      balance
    );
  });

  it("Should withdraw 50% of mint revenue to owner", async function () {
    const { capsules, owner } = await deploy();

    await capsules.setSaleIsActive(true);

    const mintCount = defaultMaxSupply;

    await mintCapsules(capsules, mintCount);

    const mintRevenue = mintPrice.mul(mintCount);

    const initialOwnerBalance = await owner.getBalance();

    await capsules.withdrawToOwner(mintRevenue.div(2));

    expect(await owner.getBalance()).to.be.gte(
      initialOwnerBalance
        .add(mintRevenue.div(2))
        .sub(ethers.utils.parseEther("0.01")) // subtract to account for gas
    );
  });

  it("Set note on non-owned capsule should revert", async function () {
    const { capsules, owner } = await deploy();

    await capsules.setSaleIsActive(true);

    await mintCapsules(capsules, 1);

    await capsules.transferFrom(
      owner.address,
      "0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8",
      1
    );

    await expect(
      capsules.setNote(1, [
        ethers.utils.hexZeroPad("0x20", 15),
        ethers.utils.hexZeroPad("0x20", 15),
        ethers.utils.hexZeroPad("0x20", 15),
        ethers.utils.hexZeroPad("0x20", 15),
        ethers.utils.hexZeroPad("0x20", 15),
        ethers.utils.hexZeroPad("0x20", 15),
        ethers.utils.hexZeroPad("0x20", 15),
      ])
    ).to.be.revertedWith("Capsule not owned");
  });

  it("Set valid note on owned capsule should succeed", async function () {
    const { capsules } = await deploy();

    await capsules.setSaleIsActive(true);

    await mintCapsules(capsules, 2);

    await capsules.setNote(
      1,
      [
        formatBytes15("< one! +=-_~"),
        formatBytes15(' "two"? @ # $ %'),
        formatBytes15("  three ` & <>"),
        formatBytes15("   'four'; < "),
        formatBytes15("    five ..."),
        formatBytes15("{   6   } []()|"),
        formatBytes15("> max length 15"),
      ],
      {
        value: mintPrice,
      }
    );

    console.log(await capsules.imageOf(1));
    console.log(await capsules.noteOf(1, 1));
    console.log(await capsules.noteOf(1, 2));
    console.log(await capsules.noteOf(1, 3));
    console.log(await capsules.imageOf(2));
    console.log(await capsules.noteOf(2, 1));
    console.log(await capsules.noteOf(2, 2));
    console.log(await capsules.noteOf(2, 3));
  });

  it("Set invalid note on owned capsule should revert", async function () {
    const { capsules } = await deploy();

    await capsules.setSaleIsActive(true);

    await mintCapsules(capsules, 1);

    // Send string too long
    await expect(
      capsules.setNote(
        1,
        [
          formatBytes15("too long too long"),
          formatBytes15("two"),
          formatBytes15("three"),
          formatBytes15("four"),
          formatBytes15("five"),
          formatBytes15("six"),
          formatBytes15("seven"),
        ],
        {
          value: mintPrice,
        }
      )
    ).to.be.reverted;

    // Invalid character
    await expect(
      capsules.setNote(
        1,
        [
          formatBytes15("👽"),
          formatBytes15("two"),
          formatBytes15("three"),
          formatBytes15("four"),
          formatBytes15("five"),
          formatBytes15("six"),
          formatBytes15("seven"),
        ],
        {
          value: mintPrice,
        }
      )
    ).to.be.revertedWith("Note is invalid");

    // Invalid character
    await expect(
      capsules.setNote(
        1,
        [
          formatBytes15("≠"),
          formatBytes15("two"),
          formatBytes15("three"),
          formatBytes15("four"),
          formatBytes15("five"),
          formatBytes15("six"),
          formatBytes15("seven"),
        ],
        {
          value: mintPrice,
        }
      )
    ).to.be.revertedWith("Note is invalid");
  });
});
