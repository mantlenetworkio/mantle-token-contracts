// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "contracts/OFT/MantleOFTUpgradeable.sol";
import "contracts/OFT/MantleOFTAdapterUpgradeable.sol";

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
    ProxyAdmin public proxyAdmin;

    function setUp() public {
        // Set deployment parameters from environment
        endpoint = vm.envAddress("LZ_ENDPOINT");
        delegate = vm.envAddress("DELEGATE");
        proxyAdmin = ProxyAdmin(vm.envAddress("PROXY_ADMIN"));
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

        if (address(proxyAdmin) == address(0)) {
            proxyAdmin = new ProxyAdmin(deployerAddress);
            console.log("ProxyAdmin deployed at:", address(proxyAdmin));
            console.log("ProxyAdmin owner:", proxyAdmin.owner());
        }

        MantleOFTAdapterUpgradeable impl = new MantleOFTAdapterUpgradeable(mntAddress, endpoint);
        console.log("Implementation deployed at:", address(impl));

        // Deploy MantleOFTAdapter
        bytes32 salt = keccak256(bytes("MantleOFTAdapterUpgradeable"));
        address expectedOFTAdapter = _getDeterministicAddress(
            salt,
            type(TransparentUpgradeableProxy).creationCode,
            abi.encode(
                address(impl),
                address(proxyAdmin),
                abi.encodeWithSelector(MantleOFTAdapterUpgradeable.initialize.selector, delegate)
            )
        );
        console.log("Expected OFTAdapter:", expectedOFTAdapter);
        TransparentUpgradeableProxy oftAdapterContract = new TransparentUpgradeableProxy{ salt: salt }(
            address(impl),
            address(proxyAdmin),
            abi.encodeWithSelector(MantleOFTAdapterUpgradeable.initialize.selector, delegate)
        );
        oftAdapter = address(oftAdapterContract);
        if (oftAdapter != expectedOFTAdapter) {
            revert("Proxy address mismatch");
        }
        console.log("MantleOFTAdapter deployed at:", oftAdapter);

        vm.stopBroadcast();

        console.log("OFTAdapter Token:", MantleOFTAdapterUpgradeable(oftAdapter).token());
        console.log("OFTAdapter Approval Required:", MantleOFTAdapterUpgradeable(oftAdapter).approvalRequired());

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

        if (address(proxyAdmin) == address(0)) {
            proxyAdmin = new ProxyAdmin(deployerAddress);
            console.log("ProxyAdmin deployed at:", address(proxyAdmin));
            console.log("ProxyAdmin owner:", proxyAdmin.owner());
        }

        MantleOFTUpgradeable impl = new MantleOFTUpgradeable(endpoint);
        console.log("Implementation deployed at:", address(impl));

        // Deploy the proxy contract
        bytes32 salt = keccak256(bytes("MantleOFTUpgradeable"));
        address expectedOFT = _getDeterministicAddress(
            salt,
            type(TransparentUpgradeableProxy).creationCode,
            abi.encode(
                address(impl),
                address(proxyAdmin),
                abi.encodeWithSelector(MantleOFTUpgradeable.initialize.selector, TOKEN_NAME, TOKEN_SYMBOL, delegate)
            )
        );

        console.log("Expected proxy address:", expectedOFT);
        TransparentUpgradeableProxy proxyContract = new TransparentUpgradeableProxy{ salt: salt }(
            address(impl),
            address(proxyAdmin),
            abi.encodeWithSelector(MantleOFTUpgradeable.initialize.selector, TOKEN_NAME, TOKEN_SYMBOL, delegate)
        );
        oft = address(proxyContract);
        if (oft != expectedOFT) {
            revert("Proxy address mismatch");
        }
        console.log("Proxy deployed at:", oft);

        vm.stopBroadcast();

        console.log("MantleOFT Token Name:", MantleOFTUpgradeable(oft).name());
        console.log("MantleOFT Token Symbol:", MantleOFTUpgradeable(oft).symbol());
        console.log("MantleOFT Token Decimals:", MantleOFTUpgradeable(oft).decimals());
        console.log("MantleOFT Approval Required:", MantleOFTUpgradeable(oft).approvalRequired());

        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("MantleOFT:", oft);
    }

    function _getDeterministicAddress(bytes32 salt, bytes memory creationCode, bytes memory initData)
        internal
        pure
        returns (address)
    {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            address(0x4e59b44847b379578588920cA78FbF26c0B4956C),
                            salt,
                            keccak256(abi.encodePacked(creationCode, initData))
                        )
                    )
                )
            )
        );
    }
}
