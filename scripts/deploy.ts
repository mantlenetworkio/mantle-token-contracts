import { ethers } from 'hardhat';
import { upgrades } from 'hardhat';
import { Contract, ContractFactory } from 'ethers';
import { MantleTokenMigrator__factory, L1MantleToken__factory } from "../typechain";

async function main(): Promise<void> {
  const [deployer] = await ethers.getSigners();
  const mintAmount = ethers.utils.parseEther("10000000000");
  const L1MantleToken = new L1MantleToken__factory(deployer);
  // deploy L1MantleToken
  const l1MantleToken = await upgrades.deployProxy(L1MantleToken, [mintAmount, deployer.address])
  await l1MantleToken.deployed();

  // BitDAO token address
  const bitTokenAddress = '0x6d3d7b3779655405eE64662E33b79A4699845C3e'

  //deploy MantleTokenMigrator
  const MantleTokenMigrator = new MantleTokenMigrator__factory(deployer);
  const mantleTokenMigrator = await MantleTokenMigrator.deploy(bitTokenAddress);

  await mantleTokenMigrator.setMantle(l1MantleToken.address);
  console.log('l1MantleToken(proxy) address: ', l1MantleToken.address)
  console.log('mantleTokenMigrator address: ', mantleTokenMigrator.address)

  //TODO: need transfer owner to multi-sig account
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
