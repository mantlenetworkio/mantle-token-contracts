import { ethers, upgrades } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { L1MantleToken__factory } from "../typechain";
import { time, mine } from "@nomicfoundation/hardhat-network-helpers";
// import { expectEvent } from "@openzeppelin/test-helpers";

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
  describe("Upgrades", async () => {
    const sendAmount = ethers.utils.parseEther("100");
    const receiverAmount = ethers.utils.parseEther("10");
    beforeEach(async () => {
      // transfer to owner
      const [deployer, owner] = await ethers.getSigners();
      const deployerIns = new L1MantleToken__factory(deployer).attach(l1MantleTokenAddress);
      await deployerIns.transfer(owner.address, sendAmount);
    });
    it("Should transfer success when use transferProxyAdminOwnership", async () => {
      const [deployer, owner, receiver] = await ethers.getSigners();
      await upgrades.admin.transferProxyAdminOwnership(owner.address, deployer);
      const ownerIns = new L1MantleToken__factory(owner).attach(l1MantleTokenAddress);

      await ownerIns.transfer(receiver.address, receiverAmount);
      expect(await ownerIns.balanceOf(receiver.address)).to.eq(receiverAmount);
    });
    // it("Should transfer failed when use changeProxyAdmin", async () => {
    //   const [deployer, owner, receiver] = await ethers.getSigners();
    //   await upgrades.admin.changeProxyAdmin(l1MantleTokenAddress, owner.address, deployer);
    //   const ownerIns = new L1MantleToken__factory(owner).attach(l1MantleTokenAddress);
    //   expect(ownerIns.transfer(receiver.address, receiverAmount)).to.be.revertedWith(
    //     "TransparentUpgradeableProxy: admin cannot fallback to proxy target",
    //   );
    // });
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
      const [deployer, user1] = await ethers.getSigners();
      const amount = ethers.utils.parseEther("1000");
      const user1Instance = new L1MantleToken__factory(user1).attach(l1MantleTokenAddress);
      const res1 = await user1Instance.mint(amount);
      expect(await user1Instance.balanceOf(user1.address)).to.eq(amount);
      const res2 = await user1Instance.mint(amount);
      expect(res2)
        .to.emit(user1Instance, "MintAfterBlockHeight").withArgs(
          (res1.blockNumber || 0) + 1000
        )
      expect(await user1Instance.balanceOf(user1.address)).to.eq(amount);
      await mine(1000);
      await user1Instance.mint(amount);
      expect(await user1Instance.balanceOf(user1.address)).to.eq(ethers.utils.parseEther("2000"));
    })
    // it("Should fail when mint doesn't meet the rules", async () => {
    //   const [deployer, user] = await ethers.getSigners();
    //   const userInstance = new L1MantleToken__factory(user).attach(l1MantleTokenAddress);
      
    //   const amount1 = ethers.utils.parseEther("200000000")
    //   const amount2 = ethers.utils.parseEther("200000001")

    //   await expect(userInstance.mint(user.address, amount1)).to.be.revertedWith(
    //     "Ownable: caller is not the owner",
    //   );

    //   const deployerInstance = new L1MantleToken__factory(deployer).attach(l1MantleTokenAddress);
    //   await deployerInstance.setMintCapNumerator(200);
    //   await expect(deployerInstance.mint(deployer.address, amount2)).to.be.revertedWith(
    //     "MANTLE: MINT_TOO_MUCH",
    //   );
    //   await expect(deployerInstance.mint(deployer.address, amount1)).to.be.revertedWith(
    //     "MANTLE: MINT_TOO_EARLY",
    //   );
    // });

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
  describe("Vote", async () => {
    const sendAmount = ethers.utils.parseEther("100");
    beforeEach(async () => {
      const [deployer, holder, recipient, holderDelegatee, other1, other2] = await ethers.getSigners();
      const l1MantleTokenInstance = new L1MantleToken__factory(deployer).attach(l1MantleTokenAddress);
      // const sendAmount = ethers.utils.parseEther("100");
      await l1MantleTokenInstance.transfer(holder.address, sendAmount);
    });
    describe('call', async () => {
      describe('set delegation', async () => {
        it('delegation with balance', async function () {
          const [deployer, holder] = await ethers.getSigners();
          const holderIns = new L1MantleToken__factory(holder).attach(l1MantleTokenAddress);
          expect(await holderIns.delegates(holder.address)).to.be.equal(ethers.constants.AddressZero);
        
          const res = await holderIns.delegate(holder.address)
          expect(res)
				    .to.emit(holderIns, "DelegateChanged").withArgs(holder.address, ethers.constants.AddressZero, holder.address)
				    .to.emit(holderIns, "DelegateVotesChanged").withArgs(holder.address, 0, sendAmount)

          expect(await holderIns.delegates(holder.address)).to.be.equal(holder.address);
          expect(await holderIns.getVotes(holder.address)).to.be.equal(sendAmount);
          const timepoint = res.blockNumber || 0;
          expect(await holderIns.getPastVotes(holder.address, timepoint - 1)).to.be.equal(0);
          await mine();
          expect(await holderIns.getPastVotes(holder.address, timepoint)).to.be.equal(sendAmount);
        });
    
        it('delegation without balance', async function () {
          const [deployer, holder, recipient, other1] = await ethers.getSigners();
          const other1Ins = new L1MantleToken__factory(other1).attach(l1MantleTokenAddress);
          expect(await other1Ins.delegates(other1.address)).to.be.equal(ethers.constants.AddressZero);
    
          const res = await other1Ins.delegate(other1.address);

          expect(res)
				    .to.emit(other1Ins, "DelegateChanged").withArgs(other1.address, ethers.constants.AddressZero, other1.address)
            .to.not.emit(other1Ins, "DelegateVotesChanged");
    
          expect(await other1Ins.delegates(other1.address)).to.be.equal(other1.address);
        });
      })
    })
  })
});
