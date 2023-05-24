import { ethers } from 'hardhat';
import { upgrades } from 'hardhat';
import { MantleTokenMigrator__factory, L1MantleToken__factory } from "../typechain";

async function main(): Promise<void> {
  const L1MantleTokenOwner = '0x3e8598212a5E859b6eFF292Bdcbf7A9B183411be'
  const MantleTokenMigratorOwner = '0x3e8598212a5E859b6eFF292Bdcbf7A9B183411be'

  const [deployer] = await ethers.getSigners();
  const mintAmount = ethers.utils.parseEther("10000000000");
  const L1MantleToken = new L1MantleToken__factory(deployer);
  // deploy L1MantleToken
  const l1MantleToken = await upgrades.deployProxy(L1MantleToken, [mintAmount, L1MantleTokenOwner])
  await l1MantleToken.deployed();
  await upgrades.admin.transferProxyAdminOwnership(L1MantleTokenOwner, deployer);

  // BitDAO token address
  const bitTokenAddress = '0x6d3d7b3779655405eE64662E33b79A4699845C3e'
  const goerliMigrationTreasury = '0x2E2c335d83C3e2e9a6928f9775380949c66Ee677'

  //deploy MantleTokenMigrator
  const MantleTokenMigrator = new MantleTokenMigrator__factory(deployer);
  const mantleTokenMigrator = await MantleTokenMigrator.deploy(
    bitTokenAddress,
    l1MantleToken.address,
    goerliMigrationTreasury,
    314,
    100
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
