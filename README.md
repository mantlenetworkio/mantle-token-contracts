# Mantle Token
This repository contains the Mantle token contract and the on chain migration mechanism. 
## Installation Prerequites
This repository uses both the Hardhat and Foundry smart contract development frameworks. 

Install the following on your machine:
1. [Hardhat](https://www.npmjs.com/package/hardhat)
1. [Foundry](https://book.getfoundry.sh/getting-started/installation)

## Install Repo
Run 
```shell
cp .env.example .env
```
to establish a test configuration file.

Then compile the contracts with:
```shell
forge build
```
You should see a `Compiler run successful` messaage upon successful build. 

## Testing
Testing with Forge:
```shell
forge test
```

Testing with Hardhat:
```shell
npx hardhat test
```

## Deployment
### Locally
```shell
npx hardhat node
npx hardhat run scripts/deploy.ts
```