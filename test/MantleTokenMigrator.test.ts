import { ethers, upgrades } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { MantleTokenMigrator__factory, L1MantleToken__factory, ERC20Mock__factory } from "../typechain";

chai.use(solidity);
const { expect } = chai;

describe("MantleTokenMigrator", () => {
  let l1MantleTokenAddress: string;
  let ERC20MockAddress: string;
  let mtmAddress: string;
  const mintAmount = ethers.utils.parseEther("10000000000");

  beforeEach(async () => {
    const [deployer] = await ethers.getSigners();
    // deploy L1MantleToken
    const L1MantleToken = new L1MantleToken__factory(deployer);
    const l1MantleToken = await upgrades.deployProxy(L1MantleToken, [mintAmount, deployer.address])
    await l1MantleToken.deployed();
    l1MantleTokenAddress = l1MantleToken.address;
    // deploy Mock ERC20
    const ERC20Mock = new ERC20Mock__factory(deployer);
    const erc20Mock = await ERC20Mock.deploy();
    ERC20MockAddress = erc20Mock.address;
    // deploy MantleTokenMigrator
    const MantleTokenMigrator = new MantleTokenMigrator__factory(deployer);
    const mantleTokenMigrator = await MantleTokenMigrator.deploy(ERC20MockAddress);
    mtmAddress = mantleTokenMigrator.address;
    // setMantle for MantleTokenMigrator
    await mantleTokenMigrator.setMantle(l1MantleTokenAddress);
  });
  describe("setMantle", async () => {
    it("Should only set once", async () => {
      const [deployer] = await ethers.getSigners();
      const mtmInstance = new MantleTokenMigrator__factory(deployer).attach(mtmAddress);
      await expect(mtmInstance.setMantle(l1MantleTokenAddress)).to.be.revertedWith(
        "Already set, only can be set once",
      );
    });
    // it("Should not set zero address", async () => {
    //   const [deployer] = await ethers.getSigners();
    //   const mtmInstance = new MantleTokenMigrator__factory(deployer).attach(mtmAddress);
    //   await expect(mtmInstance.setMantle(ethers.constants.AddressZero)).to.be.revertedWith(
    //     "Zero address: mantle",
    //   );
    // });
  });
  describe("withdrawToken", async () => {
    it("Should not withdraw bit", async () => {
      const [deployer, sender, recipient] = await ethers.getSigners();
      const erc20MockInstance = new ERC20Mock__factory(sender).attach(ERC20MockAddress);
      const amount = ethers.utils.parseEther("1000")
      // mint for sender 1000 ERC20MOCK
      await erc20MockInstance.mint(sender.address, amount)
      expect(await erc20MockInstance.balanceOf(sender.address)).to.eq(amount);
      // transfer to mantleTokenMigrator contract
      await erc20MockInstance.transfer(mtmAddress, amount)
      expect(await erc20MockInstance.balanceOf(sender.address)).to.eq(0);
      // MantleTokenMigrator
      const mtmInstance = new MantleTokenMigrator__factory(deployer).attach(mtmAddress);
      await expect(mtmInstance.withdrawToken(erc20MockInstance.address, amount, recipient.address)).to.be.revertedWith(
        "Cannot withdraw: bit",
      );
    });
    it("Should withdraw mantle token", async () => {
      const [deployer, sender, recipient] = await ethers.getSigners();
      const amount = ethers.utils.parseEther("1000")
      const deployerL1MantleTokenInstance = new L1MantleToken__factory(deployer).attach(l1MantleTokenAddress);
      await deployerL1MantleTokenInstance.transfer(mtmAddress, amount)
      expect(await deployerL1MantleTokenInstance.balanceOf(mtmAddress)).to.eq(amount);

      const mtmInstance = new MantleTokenMigrator__factory(deployer).attach(mtmAddress);
      await mtmInstance.withdrawToken(deployerL1MantleTokenInstance.address, amount, recipient.address)
      expect(await deployerL1MantleTokenInstance.balanceOf(mtmAddress)).to.eq(0);
      expect(await deployerL1MantleTokenInstance.balanceOf(recipient.address)).to.eq(amount);
    });
  });
  describe("migrate", async () => {
    it("Should swap bit to mantle", async () => {
      const amount = ethers.utils.parseEther("1000")
      const amount2 = ethers.utils.parseEther("10000")
      const [deployer, sender, recipient] = await ethers.getSigners();
      // sender mint 1000 ERC20MOCK
      const erc20MockInstance = new ERC20Mock__factory(sender).attach(ERC20MockAddress);
      await erc20MockInstance.mint(sender.address, amount);

      // transfer 10000 l1MantleToken to MantleTokenMigrator contract
      const l1MantleTokenInstance = new L1MantleToken__factory(deployer).attach(l1MantleTokenAddress);
      await l1MantleTokenInstance.transfer(mtmAddress, amount2)
      expect(await l1MantleTokenInstance.balanceOf(mtmAddress)).to.eq(amount2);

      // sender approve 1000 ERC20MOCK
      await erc20MockInstance.approve(mtmAddress, amount);

      // unpause MantleTokenMigrator
      const mtmInstance = new MantleTokenMigrator__factory(deployer).attach(mtmAddress);
      await mtmInstance.unpause();

      // swap token
      const senderMtmInstance = new MantleTokenMigrator__factory(sender).attach(mtmAddress);
      await senderMtmInstance.migrate(amount);
      expect(await l1MantleTokenInstance.balanceOf(sender.address)).to.eq(ethers.utils.parseEther("3140"));
      expect(await l1MantleTokenInstance.balanceOf(mtmAddress)).to.eq(ethers.utils.parseEther("6860"));
    });
    it("Should fail when mint doesn't meet the rules", async () => {
      const amount = ethers.utils.parseEther("1000")
      const amount2 = ethers.utils.parseEther("1000")
      const [deployer, sender, recipient] = await ethers.getSigners();
      // sender mint 1000 ERC20MOCK
      const erc20MockInstance = new ERC20Mock__factory(sender).attach(ERC20MockAddress);
      await erc20MockInstance.mint(sender.address, amount);

      // transfer 1000 l1MantleToken to MantleTokenMigrator contract
      const l1MantleTokenInstance = new L1MantleToken__factory(deployer).attach(l1MantleTokenAddress);
      await l1MantleTokenInstance.transfer(mtmAddress, amount2)
      expect(await l1MantleTokenInstance.balanceOf(mtmAddress)).to.eq(amount2);

      const senderMtmInstance = new MantleTokenMigrator__factory(sender).attach(mtmAddress);

      // sender approve 1000 ERC20MOCK
      await erc20MockInstance.approve(mtmAddress, amount);

      // swap token
      await expect(senderMtmInstance.migrate(amount)).to.be.revertedWith(
        "Migration: migrate enabled",
      );

      // unpause MantleTokenMigrator
      const mtmInstance = new MantleTokenMigrator__factory(deployer).attach(mtmAddress);
      await mtmInstance.unpause();

      // swap token
      await expect(senderMtmInstance.migrate(amount)).to.be.revertedWith(
        "Insufficient: not sufficient mantle",
      );
    });
  });
});
