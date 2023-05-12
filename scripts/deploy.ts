import { ethers } from 'hardhat';
import { upgrades } from 'hardhat';
import { Contract, ContractFactory } from 'ethers';

async function main(): Promise<void> {
  // const [deployer] = await ethers.getSigners();

  const L1MantleToken: ContractFactory = await ethers.getContractFactory(
    'L1MantleToken',
  );

  // 0x0265B3921E3226aF7B2Fc431385b4157E0c762Db
  const l1MantleToken = await upgrades.deployProxy(L1MantleToken, [10000000000000000000000000000n, 0x0265B3921E3226aF7B2Fc431385b4157E0c762Db], { initializer: 'initialize' })

  console.log(l1MantleToken.address, " l1MantleToken(proxy) address")
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
