// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts-v4/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts-v4/proxy/transparent/ProxyAdmin.sol";
import "contracts/L1/L1MantleToken.sol";

/// @dev This script is used to deploy the L1MantleToken contract on a testnet.
/// @notice DO NOT USE THIS SCRIPT ON MAINNET.
contract DeployL1MantleToken is Script {
    // Deployment parameters
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18; // 1 billion tokens with 18 decimals

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deploying L1MantleToken...");
        console.log("Deployer address:", deployerAddress);
        console.log("Initial supply:", INITIAL_SUPPLY);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the implementation contract
        L1MantleToken implementationContract = new L1MantleToken();
        address implementation = address(implementationContract);
        console.log("Implementation deployed at:", implementation);

        // Prepare initialization data
        bytes memory initData =
            abi.encodeWithSelector(L1MantleToken.initialize.selector, INITIAL_SUPPLY, deployerAddress);

        // Deploy the proxy contract
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        console.log("ProxyAdmin deployed at:", address(proxyAdmin));
        proxyAdmin.transferOwnership(deployerAddress);
        console.log("ProxyAdmin owner:", proxyAdmin.owner());
        TransparentUpgradeableProxy proxyContract =
            new TransparentUpgradeableProxy(implementation, address(proxyAdmin), initData);
        address proxy = address(proxyContract);
        console.log("Proxy deployed at:", proxy);

        vm.stopBroadcast();

        // Verify deployment
        L1MantleToken token = L1MantleToken(proxy);
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        console.log("Total supply:", token.totalSupply());
        console.log("Owner:", token.owner());
        console.log("Next mint timestamp:", token.nextMint());
        console.log("Mint cap numerator:", token.mintCapNumerator());

        // Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Implementation:", implementation);
        console.log("Proxy:", proxy);
        console.log("Token address (use this):", proxy);
        console.log("Initial supply:", INITIAL_SUPPLY);
        console.log("Owner:", deployerAddress);
        console.log("ProxyAdmin:", address(proxyAdmin));
    }
}
