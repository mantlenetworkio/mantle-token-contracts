import { ethers } from 'hardhat';
import { upgrades } from 'hardhat';
import { MantleTokenMigrator__factory, L1MantleToken__factory } from "../typechain";

async function main(): Promise<void> {
  // TODO: L1MantleTokenOwner & MantleTokenMigratorOwner
  const L1MantleTokenOwner = 'TBD'
  const MantleTokenMigratorOwner = 'TBD'
  const migrationTreasury = 'TBD'
  // BitDAO token address
  const bitTokenAddress = '0x5a94Dc6cc85fdA49d8E9A8b85DDE8629025C42be'
  
  const [deployer] = await ethers.getSigners();
  const mintAmount = ethers.utils.parseEther("10000000000");
  const L1MantleToken = new L1MantleToken__factory(deployer);
  // deploy L1MantleToken
  const l1MantleToken = await upgrades.deployProxy(L1MantleToken, [mintAmount, L1MantleTokenOwner])
  await l1MantleToken.deployed();
  await upgrades.admin.transferProxyAdminOwnership(L1MantleTokenOwner, deployer);

  //deploy MantleTokenMigrator
  const MantleTokenMigrator = new MantleTokenMigrator__factory(deployer);
  const mantleTokenMigrator = await MantleTokenMigrator.deploy(
    bitTokenAddress,
    l1MantleToken.address,
    migrationTreasury,
    1,
    1
  );
  await mantleTokenMigrator.transferOwnership(MantleTokenMigratorOwner);

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
