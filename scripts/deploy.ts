import { ethers } from 'hardhat';
import { Contract, ContractFactory } from 'ethers';

async function main(): Promise<void> {
  // const [deployer] = await ethers.getSigners();

  const L1MantleToken: ContractFactory = await ethers.getContractFactory(
    'L1MantleToken',
  );
  const l1MantleToken: Contract = await L1MantleToken.deploy();
  await l1MantleToken.deployed();

  const toMint = ethers.utils.parseEther("1000");
  // await l1MantleToken.initialize(toMint, deployer.address);

  console.log('l1MantleToken deployed to: ', l1MantleToken.address);
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
