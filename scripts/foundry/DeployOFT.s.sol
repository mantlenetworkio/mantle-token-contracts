// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "contracts/OFT/MantleOFTUpgradeable.sol";
import "contracts/OFT/MantleOFTAdapterUpgradeable.sol";
import "contracts/OFT/MantleOFTHyperEVMUpgradeable.sol";

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

        // Deploy MantleOFTAdapterImpl
        MantleOFTAdapterUpgradeable impl = new MantleOFTAdapterUpgradeable(mntAddress, endpoint);
        console.log("Implementation deployed at:", address(impl));

        // Deploy MantleOFTAdapterProxy
        bytes32 salt = keccak256(bytes("MantleOFTAdapterProxy"));
        oftAdapter = _deployProxy(salt, deployerAddress);
        _initProxy(
            oftAdapter, address(impl), abi.encodeWithSelector(MantleOFTAdapterUpgradeable.initialize.selector, delegate)
        );

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

        MantleOFTUpgradeable impl = new MantleOFTUpgradeable(endpoint);
        console.log("Implementation deployed at:", address(impl));

        // Deploy the proxy contract
        bytes32 salt = keccak256(bytes("MantleOFTProxy"));
        oft = _deployProxy(salt, deployerAddress);

        bytes memory initData =
            abi.encodeWithSelector(MantleOFTUpgradeable.initialize.selector, TOKEN_NAME, TOKEN_SYMBOL, delegate);
        _initProxy(oft, address(impl), initData);

        vm.stopBroadcast();

        console.log("MantleOFT Token Name:", MantleOFTUpgradeable(oft).name());
        console.log("MantleOFT Token Symbol:", MantleOFTUpgradeable(oft).symbol());
        console.log("MantleOFT Token Decimals:", MantleOFTUpgradeable(oft).decimals());
        console.log("MantleOFT Approval Required:", MantleOFTUpgradeable(oft).approvalRequired());

        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("MantleOFT:", oft);
    }

    function deployOFTHyperEVM() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deploying OFT contracts...");
        console.log("Deployer address:", deployerAddress);
        console.log("LayerZero Endpoint:", endpoint);
        console.log("Delegate:", delegate);

        vm.startBroadcast(deployerPrivateKey);

        MantleOFTHyperEVMUpgradeable impl = new MantleOFTHyperEVMUpgradeable(endpoint);
        console.log("Implementation deployed at:", address(impl));

        // Deploy the proxy contract
        bytes32 salt = keccak256(bytes("MantleOFTProxy"));
        oft = _deployProxy(salt, deployerAddress);

        bytes memory initData =
            abi.encodeWithSelector(MantleOFTHyperEVMUpgradeable.initialize.selector, TOKEN_NAME, TOKEN_SYMBOL, delegate);
        _initProxy(oft, address(impl), initData);

        vm.stopBroadcast();

        // try and check HyperCoreDeployer
        vm.prank(delegate);
        bytes32 slot = keccak256(bytes("HyperCore deployer"));
        MantleOFTHyperEVMUpgradeable(oft).setHyperCoreDeployer(address(10));
        require(vm.load(oft, slot) == bytes32(uint256(10)), "HyperCoreDeployer mismatch");

        console.log("MantleOFT Token Name:", MantleOFTHyperEVMUpgradeable(oft).name());
        console.log("MantleOFT Token Symbol:", MantleOFTHyperEVMUpgradeable(oft).symbol());
        console.log("MantleOFT Token Decimals:", MantleOFTHyperEVMUpgradeable(oft).decimals());
        console.log("MantleOFT Approval Required:", MantleOFTHyperEVMUpgradeable(oft).approvalRequired());

        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("MantleOFT:", oft);
    }

    function _deployProxy(bytes32 salt, address deployer) internal returns (address) {
        address tempImpl = 0x4e59b44847b379578588920cA78FbF26c0B4956C; // we use default create2 factory as a temp impl
        address expectedAddress = _getDeterministicAddress(
            salt, type(TransparentUpgradeableProxy).creationCode, abi.encode(tempImpl, deployer, bytes(""))
        );

        // If the proxy is already deployed at the expected address, do nothing
        if (expectedAddress.code.length != 0) {
            console.log("Proxy already deployed at:", expectedAddress);
            return expectedAddress;
        }

        TransparentUpgradeableProxy proxyContract =
            new TransparentUpgradeableProxy{ salt: salt }(tempImpl, deployer, bytes(""));
        if (address(proxyContract) != expectedAddress) {
            revert("Proxy address mismatch");
        }
        console.log("Proxy deployed at:", address(proxyContract));
        return address(proxyContract);
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

    function _initProxy(address proxy, address impl, bytes memory initData) internal {
        bytes32 slot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        address admin = address(uint160(uint256(vm.load(proxy, slot))));
        ProxyAdmin(admin).upgradeAndCall(ITransparentUpgradeableProxy(proxy), impl, initData);
    }
}
