// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy,
    ERC1967Utils
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { stdToml } from "forge-std/StdToml.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @title BaseScript
/// @notice Base script with common functions for all scripts
contract BaseScript is Script {
    // Deployer
    uint256 deployerPrivateKey;
    address deployerAddress;

    // Network info
    string public networkName;
    string public networkKey;
    bool public isMainnet;

    // Config
    string constant CONFIG_TOML_PATH = "scripts/foundry/oft.config.toml";
    string public config;

    // Deployment
    string constant DEPLOYMENT_JSON_PATH = "scripts/foundry/oft.deployment.json";
    string public deployment;

    function setUp() public virtual {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployerAddress = vm.addr(deployerPrivateKey);
        console.log("deployerAddress", deployerAddress);

        (networkName, isMainnet) = _getNetworkInfo();
        networkKey = isMainnet ? "mainnet" : "testnet";

        config = vm.readFile(CONFIG_TOML_PATH);
        deployment = vm.readFile(DEPLOYMENT_JSON_PATH);
    }

    function _getNetworkInfo() internal view returns (string memory name, bool mainnet) {
        uint256 chainid = block.chainid;
        if (chainid == 1) {
            return ("eth", true);
        } else if (chainid == 56) {
            return ("bsc", true);
        } else if (chainid == 999) {
            return ("hyper", true);
        } else if (chainid == 11155111) {
            return ("eth", false);
        } else if (chainid == 97) {
            return ("bsc", false);
        } else if (chainid == 998) {
            return ("hyper", false);
        } else {
            revert("Unknown network");
        }
    }

    function _create2(string memory saltStr, bytes memory creationCode, bytes memory args)
        internal
        returns (address impl)
    {
        bytes32 salt = keccak256(bytes(saltStr));
        address expectedAddress = _getDeterministicAddress(salt, creationCode, args);
        if (expectedAddress.code.length != 0) {
            console.log(saltStr, "already deployed at", expectedAddress);
            return expectedAddress;
        }
        bytes memory code = abi.encodePacked(creationCode, args);
        assembly {
            impl := create2(0, add(code, 0x20), mload(code), salt)
            if iszero(impl) { revert(0, 0) }
        }
        if (impl != expectedAddress) {
            revert("Impl address mismatch");
        }
        console.log(saltStr, "deployed at", expectedAddress);
        return expectedAddress;
    }

    function _deployProxy(address impl, address deployer, bytes memory initData) internal returns (address) {
        TransparentUpgradeableProxy proxyContract = new TransparentUpgradeableProxy(impl, deployer, initData);
        console.log("Proxy deployed at:", address(proxyContract));
        console.log("Proxy initialized with implementation:", impl);
        return address(proxyContract);
    }

    function _deployAndUpgradeProxyAtDeterministicAddress(
        string memory saltStr,
        address impl,
        address deployer,
        bytes memory initData
    ) internal returns (address) {
        address tempImpl = 0x4e59b44847b379578588920cA78FbF26c0B4956C; // we use default create2 factory as a temp impl
        bytes32 salt = keccak256(bytes(saltStr));
        address expectedAddress = _getDeterministicAddress(
            salt, type(TransparentUpgradeableProxy).creationCode, abi.encode(tempImpl, deployer, bytes(""))
        );

        // If the proxy is already deployed at the expected address, do nothing
        if (expectedAddress.code.length != 0) {
            console.log("Proxy already deployed at:", expectedAddress);
            _upgradeProxy(expectedAddress, impl, bytes(""));
        } else {
            TransparentUpgradeableProxy proxyContract =
                new TransparentUpgradeableProxy{ salt: salt }(tempImpl, deployer, bytes(""));
            if (address(proxyContract) != expectedAddress) {
                revert("Proxy address mismatch");
            }
            console.log("Proxy deployed at:", expectedAddress);
            _upgradeProxy(expectedAddress, impl, initData);
        }
        return expectedAddress;
    }

    function _getDeterministicAddress(bytes32 salt, bytes memory creationCode, bytes memory args)
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
                            keccak256(abi.encodePacked(creationCode, args))
                        )
                    )
                )
            )
        );
    }

    function _upgradeProxy(address proxy, address impl, bytes memory callData) internal {
        address oldImpl = address(uint160(uint256(vm.load(proxy, ERC1967Utils.IMPLEMENTATION_SLOT))));
        console.log("oldImpl", oldImpl);
        if (oldImpl == impl) {
            console.log("Proxy's current implementation is the same as the new implementation:", impl);
            return;
        }
        address admin = address(uint160(uint256(vm.load(proxy, ERC1967Utils.ADMIN_SLOT))));
        ProxyAdmin(admin).upgradeAndCall(ITransparentUpgradeableProxy(proxy), impl, callData);
        console.log("Proxy upgraded to implementation:", impl);
    }

    function _readDeployment(string memory key) internal view returns (address) {
        return vm.parseJsonAddress(deployment, key);
    }

    /// @notice If the key is not existed, manually add it to the json file before writing
    function _writeDeployment(string memory key, address value) internal {
        if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
            vm.writeJson(Strings.toChecksumHexString(value), DEPLOYMENT_JSON_PATH, key);
        }
    }
}
