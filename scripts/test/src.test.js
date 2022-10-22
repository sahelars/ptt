const { ethers } = require("hardhat");
const { expect } = require("chai");
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");
const database = require("./database.json");
const signers = require("../modules/signers.js");
const deployer = require("../modules/deployer.js");
const base64 = require("../modules/base64.js");
const time = require("../modules/time.js");

const contract = "PTT";

function merkle(database) {
  const leafNodes = database.map((num) => keccak256(num));
  const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });
  const rootHash = merkleTree.getRoot();
  const root = "0x" + rootHash.toString("hex");
  return [merkleTree, root];
}

function proof(database, code) {
  var data = keccak256(code);
  var merkleProof = merkle(database)[0].getHexProof(data);
  return merkleProof;
}

describe(`${contract} contract test`, function () {
  it("Passed", async function () {
    const addrs = await signers(2);
    const Token = await deployer(contract, addrs[0]);
    await Token.connect(addrs[0]).mint(merkle(database)[1]);
    expect(await Token.ownerOf(1)).to.equal(addrs[0].address);
    await Token.connect(addrs[1]).initializeOffer(addrs[1].address, 1, {
      value: String(21000),
    });
    expect(
      await Token.isValidTransferCode(1, "1", proof(database, "1"))
    ).to.equal(true);
    expect(await Token.ownerOf(1)).to.equal(addrs[0].address);
    await Token.connect(addrs[0]).acceptOffer(
      addrs[0].address,
      addrs[1].address,
      1
    );
    expect(
      await Token.isValidTransferCode(1, "1", proof(database, "1"))
    ).to.equal(true);
    expect(
      await Token.isValidTransferCode(1, "2", proof(database, "2"))
    ).to.equal(true);
    expect(await Token.ownerOf(1)).to.equal(addrs[0].address);
    await Token.connect(addrs[1]).transfer(
      addrs[0].address,
      addrs[1].address,
      1,
      "1",
      proof(database, "1")
    );
    expect(
      await Token.isValidTransferCode(1, "1", proof(database, "1"))
    ).to.equal(false);
    expect(
      await Token.isValidTransferCode(1, "2", proof(database, "2"))
    ).to.equal(true);
    expect(await Token.ownerOf(1)).to.equal(addrs[1].address);
  });
});
