// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseScript.s.sol";
import { MantleOFTUpgradeable } from "contracts/OFT/MantleOFTUpgradeable.sol";
import { MantleOFTAdapterUpgradeable } from "contracts/OFT/MantleOFTAdapterUpgradeable.sol";
import { MantleOFTHyperEVMUpgradeable } from "contracts/OFT/MantleOFTHyperEVMUpgradeable.sol";
import { HyperLiquidComposer } from "@layerzerolabs/hyperliquid-composer/contracts/HyperLiquidComposer.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title OFTDeploymentScript
/// @notice Script for deploying OFT and OFTAdapter contracts
/// @dev This script deploys both OFT (native token) and OFTAdapter (for existing tokens)
contract OFTDeploymentScript is BaseScript {
    using stdToml for string;

    // Deployment parameters
    string public constant TOKEN_NAME = "Mantle";
    string public constant TOKEN_SYMBOL = "MNT";
    uint8 public constant TOKEN_DECIMALS = 18;

    // Contract addresses
    address public mnt;
    address public oft;
    address public oftAdapter;
    address public endpoint;
    address public delegate;

    // Salts
    string public oftAdapterImplSalt;
    string public oftImplSalt;
    string public oftProxySalt;

    // HyperLiquid Composer parameters
    uint64 public coreIndexId;
    int64 public assetDecimalDiff;

    function setUp() public override {
        super.setUp();

        endpoint = config.readAddress(string.concat(".lz.", networkName, ".endpoint"));
        delegate = config.readAddress(string.concat(".deploy.delegate"));
        mnt = config.readAddress(".mnt");
        oftAdapter = _readDeployment(string.concat(".oft.eth.", networkKey));
        oft = _readDeployment(string.concat(".oft.", networkName, ".", networkKey));
        oftAdapterImplSalt = config.readString(".salt.oft_adapter_impl");
        oftImplSalt = config.readString(".salt.oft_impl");
        oftProxySalt = config.readString(".salt.oft_proxy");

        coreIndexId = uint64(config.readUint(string.concat(".deploy.hyperliquid_composer.core_index_id")));
        assetDecimalDiff = int64(config.readInt(string.concat(".deploy.hyperliquid_composer.asset_decimal_diff")));

        require(endpoint != address(0), "Endpoint is not set");
        require(delegate != address(0), "Delegate is not set");
        require(mnt != address(0), "MNT is not set");
    }

    /// @dev use: FOUNDRY_PROFILE=sepolia forge script scripts/foundry/deployOFT.s.sol --sig "deployOFTAdapter()"
    function deployOFTAdapter() public {
        require(bytes32(bytes(networkName)) == bytes32(bytes("eth")), "You can only deploy OFTAdapter on Ethereum");
        console.log("Deploying OFTAdapter contracts...");
        console.log("Deployer address:", deployerAddress);
        console.log("Existing MNT:", mnt);
        console.log("LayerZero Endpoint:", endpoint);
        console.log("Delegate:", delegate);

        _startBroadcast();

        address impl =
            _create2(oftAdapterImplSalt, type(MantleOFTAdapterUpgradeable).creationCode, abi.encode(mnt, endpoint));

        if (oftAdapter == address(0)) {
            oftAdapter = _deployProxy(
                impl, deployerAddress, abi.encodeWithSelector(MantleOFTAdapterUpgradeable.initialize.selector, delegate)
            );
            _writeDeployment(string.concat(".oft.", networkName, ".", networkKey), oftAdapter);
        } else {
            console.log("OFTAdapter already deployed at", oftAdapter);
            _upgradeProxy(oftAdapter, impl, bytes(""));
        }

        _stopBroadcast();

        console.log("OFTAdapter Token:", MantleOFTAdapterUpgradeable(oftAdapter).token());
        console.log("OFTAdapter Approval Required:", MantleOFTAdapterUpgradeable(oftAdapter).approvalRequired());

        // Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("OFTAdapter:", oftAdapter);
    }

    /// @dev use: FOUNDRY_PROFILE=bsc-testnet forge script scripts/foundry/deployOFT.s.sol --sig "deployOFT()"
    function deployOFT() public {
        require(
            bytes32(bytes(networkName)) != bytes32(bytes("eth")), "You can only deploy OFT on non-Ethereum networks"
        );
        console.log("Deploying OFT on", networkName);
        console.log("Deployer address:", deployerAddress);
        console.log("LayerZero Endpoint:", endpoint);
        console.log("Delegate:", delegate);

        bool onHyperEvm = bytes32(bytes(networkName)) == bytes32(bytes("hyper"));

        _startBroadcast();

        address impl;
        if (onHyperEvm) {
            impl = _create2(oftImplSalt, type(MantleOFTHyperEVMUpgradeable).creationCode, abi.encode(endpoint));
        } else {
            impl = _create2(oftImplSalt, type(MantleOFTUpgradeable).creationCode, abi.encode(endpoint));
        }

        oft = _deployAndUpgradeProxyAtDeterministicAddress(
            oftProxySalt,
            impl,
            deployerAddress,
            abi.encodeWithSelector(MantleOFTUpgradeable.initialize.selector, TOKEN_NAME, TOKEN_SYMBOL, delegate)
        );
        _writeDeployment(string.concat(".oft.", networkName, ".", networkKey), oft);

        _stopBroadcast();

        if (onHyperEvm) {
            // try to set and check HyperCoreDeployer
            vm.prank(delegate);
            bytes32 slot = keccak256(bytes("HyperCore deployer"));
            MantleOFTHyperEVMUpgradeable(oft).setHyperCoreDeployer(address(10));
            require(vm.load(oft, slot) == bytes32(uint256(10)), "HyperCoreDeployer mismatch");
        }

        console.log("MantleOFT Token Name:", MantleOFTUpgradeable(oft).name());
        console.log("MantleOFT Token Symbol:", MantleOFTUpgradeable(oft).symbol());
        console.log("MantleOFT Token Decimals:", MantleOFTUpgradeable(oft).decimals());
        console.log("MantleOFT Approval Required:", MantleOFTUpgradeable(oft).approvalRequired());

        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("MantleOFT:", oft);
    }

    /// @dev use: FOUNDRY_PROFILE=hyper-testnet forge script scripts/foundry/DeployOFT.s.sol --sig "deployHyperLiquidComposer()"
    function deployHyperLiquidComposer() public {
        require(oft != address(0), "OFT is not set");
        require(coreIndexId != 0, "Core Index ID is not set");
        require(assetDecimalDiff != 0, "Asset Decimal Diff is not set");

        console.log("Deploying HyperLiquidComposer...");
        console.log("LayerZero Endpoint:", endpoint);
        console.log("OFT:", oft);
        console.log("Core Index ID:", coreIndexId);
        console.log("Asset Decimal Diff:", assetDecimalDiff);

        _startBroadcast();

        HyperLiquidComposer composer = new HyperLiquidComposer(endpoint, oft, coreIndexId, assetDecimalDiff);

        _writeDeployment(string.concat(".hyperliquid_composer.", networkKey), address(composer));

        _stopBroadcast();

        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("HyperLiquidComposer:", address(composer));
    }

    /// @dev use: FOUNDRY_PROFILE=sepolia forge script scripts/foundry/DeployOFT.s.sol --sig "deployTimelockController()"
    function deployTimelockController() public {
        console.log("Deploying TimelockController...");
        string memory testnetConfigPath = "scripts/foundry/tl.config.testnet.toml";
        string memory mainnetConfigPath = "scripts/foundry/tl.config.mainnet.toml";

        string memory tlConfig = vm.readFile(isMainnet ? mainnetConfigPath : testnetConfigPath);

        uint256 minDelay = tlConfig.readUint(string.concat(".", networkName, ".min_delay"));
        address[] memory proposers = tlConfig.readAddressArray(string.concat(".", networkName, ".proposers"));
        address[] memory executors = tlConfig.readAddressArray(string.concat(".", networkName, ".executors"));
        address admin = tlConfig.readAddress(string.concat(".", networkName, ".admin"));

        console.log("Min Delay:", minDelay);
        for (uint256 i = 0; i < proposers.length; i++) {
            console.log("Proposer", i, proposers[i]);
            require(proposers[i] != address(0), "Proposer should not be the zero address");
        }
        for (uint256 i = 0; i < executors.length; i++) {
            console.log("Executor", i, executors[i]);
            require(executors[i] != address(0), "Executor should not be the zero address");
        }
        console.log("Admin:", admin);
        require(admin != address(0), "Admin should not be the zero address");

        address timelock = _readDeployment(string.concat(".timelock_controller.", networkName, ".", networkKey));
        if (timelock != address(0)) {
            console.log("TimelockController already deployed at", timelock);
            return;
        }

        _startBroadcast();

        TimelockController tl = new TimelockController(minDelay, proposers, executors, admin);

        _writeDeployment(string.concat(".timelock_controller.", networkName, ".", networkKey), address(tl));

        _stopBroadcast();

        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("TimelockController:", address(tl));
    }
}
