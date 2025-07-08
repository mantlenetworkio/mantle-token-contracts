// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTAdapter.sol";
import "contracts/OFT/MantleOFT.sol";
import "contracts/OFT/MantleOFTAdapter.sol";

/// @title OFTDeploymentScript
/// @notice Script for deploying OFT and OFTAdapter contracts
/// @dev This script deploys both OFT (native token) and OFTAdapter (for existing tokens)
contract OFTDeploymentScript is Script {
    // Deployment parameters
    string public constant TOKEN_NAME = "Mantle";
    string public constant TOKEN_SYMBOL = "MNT";
    uint8 public constant TOKEN_DECIMALS = 18;
    
    // Contract addresses
    address public oft;
    address public oftAdapter;
    address public endpoint;
    address public delegate;
    
    function setUp() public {
        // Set deployment parameters from environment
        endpoint = vm.envAddress("LZ_ENDPOINT");
        delegate = vm.envAddress("DELEGATE");
    }
    
    function deployOFTAdapter(address mntAddress) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        console.log("Deploying OFT contracts...");
        console.log("Deployer address:", deployerAddress);
        console.log("Existing MNT:", mntAddress);
        console.log("LayerZero Endpoint:", endpoint);
        console.log("Delegate:", delegate);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy MantleOFTAdapter
        MantleOFTAdapter oftAdapterContract = new MantleOFTAdapter(
            mntAddress,
            endpoint,
            delegate
        );
        oftAdapter = address(oftAdapterContract);
        console.log("MantleOFTAdapter deployed at:", oftAdapter);
        
        vm.stopBroadcast();
        
        console.log("OFTAdapter Token:", OFTAdapter(oftAdapter).token());
        console.log("OFTAdapter Approval Required:", OFTAdapter(oftAdapter).approvalRequired());
        
        // Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("OFTAdapter:", oftAdapter);
    }

    function deployOFT() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        console.log("Deploying OFT contracts...");
        console.log("Deployer address:", deployerAddress);
        console.log("LayerZero Endpoint:", endpoint);
        console.log("Delegate:", delegate);

        vm.startBroadcast(deployerPrivateKey);

        MantleOFT oftContract = new MantleOFT(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            endpoint,
            delegate
        );

        oft = address(oftContract);
        console.log("MantleOFT deployed at:", oft);

        vm.stopBroadcast();

        console.log("MantleOFT Token Name:", MantleOFT(oft).name());
        console.log("MantleOFT Token Symbol:", MantleOFT(oft).symbol());
        console.log("MantleOFT Token Decimals:", MantleOFT(oft).decimals());
        console.log("MantleOFT Approval Required:", MantleOFT(oft).approvalRequired());

        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("MantleOFT:", oft);
    }
}
