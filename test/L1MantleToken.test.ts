import { ethers, upgrades } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { L1MantleToken__factory } from "../typechain";
import { time } from "@nomicfoundation/hardhat-network-helpers";


chai.use(solidity);
const { expect } = chai;

describe("L1MantleToken", () => {
  let l1MantleTokenAddress: string;
  const mintAmount = ethers.utils.parseEther("10000000000");

  beforeEach(async () => {
    const [deployer] = await ethers.getSigners();
    const L1MantleToken = new L1MantleToken__factory(deployer);
    const l1MantleToken = await upgrades.deployProxy(L1MantleToken, [mintAmount, deployer.address])
    await l1MantleToken.deployed();
    l1MantleTokenAddress = l1MantleToken.address;
  });
  describe("Info", async () => {
    it("Should get some token infos", async () => {
      const [deployer] = await ethers.getSigners();
      const l1MantleTokenInstance = new L1MantleToken__factory(deployer).attach(l1MantleTokenAddress);

      expect(await l1MantleTokenInstance.name()).to.eq('Mantle');
      expect(await l1MantleTokenInstance.symbol()).to.eq('MNT');
      expect(await l1MantleTokenInstance.decimals()).to.eq(18);
    });
  });
  describe("Mint", async () => {
    it("Should mint some tokens", async () => {
      const [deployer] = await ethers.getSigners();
      const l1MantleTokenInstance = new L1MantleToken__factory(deployer).attach(l1MantleTokenAddress);

      expect(await l1MantleTokenInstance.totalSupply()).to.eq(mintAmount);
    });
    it("Should get mint owner", async () => {
      const [deployer] = await ethers.getSigners();
      const l1MantleTokenInstance = new L1MantleToken__factory(deployer).attach(l1MantleTokenAddress);

      expect(await l1MantleTokenInstance.owner()).to.eq(deployer.address);
    });
    it("Should mint when mint the rules", async () => {
      const [deployer] = await ethers.getSigners();
      const amount = ethers.utils.parseEther("200000000")
      const deployerInstance = new L1MantleToken__factory(deployer).attach(l1MantleTokenAddress);
      await deployerInstance.setMintCapNumerator(200);
      await time.increase(365 * 24 * 60 * 60)
      await deployerInstance.mint(deployer.address, amount);
      expect(await deployerInstance.totalSupply()).to.eq(ethers.utils.parseEther("10200000000"));
    })
    it("Should fail when mint doesn't meet the rules", async () => {
      const [deployer, user] = await ethers.getSigners();
      const userInstance = new L1MantleToken__factory(user).attach(l1MantleTokenAddress);
      
      const amount1 = ethers.utils.parseEther("200000000")
      const amount2 = ethers.utils.parseEther("200000001")

      await expect(userInstance.mint(user.address, amount1)).to.be.revertedWith(
        "Ownable: caller is not the owner",
      );

      const deployerInstance = new L1MantleToken__factory(deployer).attach(l1MantleTokenAddress);
      await deployerInstance.setMintCapNumerator(200);
      await expect(deployerInstance.mint(deployer.address, amount2)).to.be.revertedWith(
        "MANTLE: MINT_TOO_MUCH",
      );
      await expect(deployerInstance.mint(deployer.address, amount1)).to.be.revertedWith(
        "MANTLE: MINT_TOO_EARLY",
      );
    });

  });
  describe("Transfer", async () => {
    it("Should transfer tokens between users", async () => {
      const [deployer, receiver] = await ethers.getSigners();
      const deployerInstance = new L1MantleToken__factory(deployer).attach(l1MantleTokenAddress);

      expect(await deployerInstance.balanceOf(deployer.address)).to.eq(mintAmount);

      const sendAmount = ethers.utils.parseEther("100");
      await deployerInstance.transfer(receiver.address, sendAmount);
      expect(await deployerInstance.balanceOf(receiver.address)).to.eq(sendAmount);
    });

    it("Should fail to transfer with low balance", async () => {
      const [deployer, sender, receiver] = await ethers.getSigners();
      const deployerInstance = new L1MantleToken__factory(deployer).attach(l1MantleTokenAddress);

      const sendAmount = ethers.utils.parseEther("100");
      await deployerInstance.transfer(sender.address, sendAmount);
      expect(await deployerInstance.balanceOf(sender.address)).to.eq(sendAmount);

      const senderInstance = new L1MantleToken__factory(sender).attach(l1MantleTokenAddress);      
      const sendAmount2 = ethers.utils.parseEther("100.1");
      await expect(senderInstance.transfer(receiver.address, sendAmount2)).to.be.revertedWith(
        "ERC20: transfer amount exceeds balance",
      );
    });
  });
});
