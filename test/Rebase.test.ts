import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Rebase Tests", function () {
    const ONE_ETH = ethers.parseEther("1");
    const USDA_2K = 200000;//2k

    async function deployFixture() {

        const [owner, otherAccount] = await ethers.getSigners();

        const AlgoDollar = await ethers.getContractFactory("AlgoDollar");
        const algoDollar = await AlgoDollar.deploy();

        const WeiUsdOracle = await ethers.getContractFactory("WeiUsdOracle");
        const oracle = await WeiUsdOracle.deploy(USDA_2K);//2k

        const Rebase = await ethers.getContractFactory("Rebase");
        const rebase = await Rebase.deploy(oracle.target, algoDollar.target);

        await algoDollar.setRebase(rebase.target);
        const weisPerPenny = await oracle.getWeiRatio();
        await rebase.initialize(weisPerPenny, { value: ONE_ETH });

        return { oracle, algoDollar, rebase, otherAccount };
    }

    it("Should get parity", async function () {
        const { rebase } = await loadFixture(deployFixture);

        expect(await rebase.getParity(0)).to.equal(100);
    });

    it("Should deposit", async function () {
        const { rebase, otherAccount } = await loadFixture(deployFixture);

        const instance = rebase.connect(otherAccount);
        expect(await instance.deposit({ value: ONE_ETH }))
            .to.emit(instance, "Transfer")
            .withArgs(ethers.ZeroAddress, otherAccount.address, USDA_2K);
    });

    it("Should withdraw ETH", async function () {
        const { rebase, otherAccount } = await loadFixture(deployFixture);

        const instance = rebase.connect(otherAccount);
        await instance.deposit({ value: ONE_ETH });

        expect(await instance.withdrawEth(ONE_ETH))
            .to.emit(instance, "Transfer")
            .withArgs(otherAccount.address, ethers.ZeroAddress, USDA_2K);
    });

    it("Should withdraw USDA", async function () {
        const { rebase, otherAccount } = await loadFixture(deployFixture);

        const instance = rebase.connect(otherAccount);
        await instance.deposit({ value: ONE_ETH });

        expect(await instance.withdrawUsda(USDA_2K))
            .to.emit(instance, "Transfer")
            .withArgs(otherAccount.address, ethers.ZeroAddress, USDA_2K);
    });

    it("Should adjust supply down", async function () {
        const { rebase, oracle, algoDollar, otherAccount } = await loadFixture(deployFixture);

        await oracle.subscribe(rebase.target);

        const instance = rebase.connect(otherAccount);
        await instance.deposit({ value: ONE_ETH });

        const oldSupply = await algoDollar.totalSupply();
        await oracle.setEthPrice(USDA_2K * 0.95);//-5%
        const newSupply = await algoDollar.totalSupply();

        expect(newSupply).to.be.equal(Number(oldSupply) * 0.95);
        expect(await rebase.getParity(0)).to.equal(100);
    });

    it("Should adjust supply up", async function () {
        const { rebase, oracle, algoDollar, otherAccount } = await loadFixture(deployFixture);

        await oracle.subscribe(rebase.target);

        const instance = rebase.connect(otherAccount);
        await instance.deposit({ value: ONE_ETH });

        const oldSupply = await algoDollar.totalSupply();
        await oracle.setEthPrice(USDA_2K * 1.05);//+5%
        const newSupply = await algoDollar.totalSupply();

        expect(newSupply).to.be.equal(Number(oldSupply) * 1.05);
        expect(await rebase.getParity(0)).to.equal(100);
    });
});