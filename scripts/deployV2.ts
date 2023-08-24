import { ethers } from 'hardhat';
import { upgrades } from 'hardhat';
import { MantleTokenMigratorV2__factory} from "../typechain";

async function main(): Promise<void> {
    const MantleTokenMigratorV2Owner = ''
  
    const [deployer] = await ethers.getSigners();
  
    // BitDAO token address
    const bitTokenAddress = '0x6d3d7b3779655405eE64662E33b79A4699845C3e'
    const goerliMigrationTreasury = '0x2E2c335d83C3e2e9a6928f9775380949c66Ee677'
    const goerliL1MantleToken = '0xc1dC2d65A2243c22344E725677A3E3BEBD26E604'
  
    //deploy MantleTokenMigrator
    const MantleTokenMigrator = new MantleTokenMigratorV2__factory(deployer);
    const mantleTokenMigrator = await MantleTokenMigrator.deploy(
      bitTokenAddress,
      goerliL1MantleToken,
      goerliMigrationTreasury
    );
    await mantleTokenMigrator.transferOwnership(MantleTokenMigratorV2Owner);
  
    console.log('mantleTokenMigratorV2 address: ', mantleTokenMigrator.address)
  
    //TODO: need transfer owner to multi-sig account
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
      console.error(error);
      process.exit(1);
    });