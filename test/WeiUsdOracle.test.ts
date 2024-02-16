import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Oracle Tests", function () {

  const ONE_ETH = ethers.parseEther("1");
  const USDA_2K = 200000;//2k

  async function deployFixture() {

    const AlgoDollar = await ethers.getContractFactory("AlgoDollar");
    const algoDollar = await AlgoDollar.deploy();

    const WeiUsdOracle = await ethers.getContractFactory("WeiUsdOracle");
    const oracle = await WeiUsdOracle.deploy(USDA_2K);

    const Rebase = await ethers.getContractFactory("Rebase");
    const rebase = await Rebase.deploy(oracle.target, algoDollar.target);

    await algoDollar.setRebase(rebase.target);
    
    const weisPerPenny = await oracle.getWeiRatio();
    await rebase.initialize(weisPerPenny, { value: ONE_ETH });

    return { oracle, rebase };
  }

  it("Should get the wei ratio", async function () {
    const { oracle } = await loadFixture(deployFixture);

    //1 * 10 ** 18 wei = 2k * 100 cents
    expect(await oracle.getWeiRatio()).to.equal("5000000000000");
  });

  it("Should set the ETH price", async function () {
    const { oracle } = await loadFixture(deployFixture);
    await oracle.setEthPrice(400000);
    expect(await oracle.getWeiRatio()).to.equal("2500000000000");
  });

  it("Should subscribe", async function () {
    const { oracle, rebase } = await loadFixture(deployFixture);
    await expect(oracle.subscribe(rebase.target))
      .to.emit(oracle, "Subscribed")
      .withArgs(rebase.target);
  });

  it("Should unsubscribe", async function () {
    const { oracle, rebase } = await loadFixture(deployFixture);

    await oracle.subscribe(rebase.target);

    await expect(oracle.unsubscribe(rebase.target))
      .to.emit(oracle, "Unsubscribed")
      .withArgs(rebase.target);
  });

  it("Should update all", async function () {
    const { oracle, rebase } = await loadFixture(deployFixture);

    await oracle.subscribe(rebase.target);

    await expect(oracle.setEthPrice(400000))
      .to.emit(oracle, "AllUpdated")
      .withArgs([rebase.target]);
  });
});