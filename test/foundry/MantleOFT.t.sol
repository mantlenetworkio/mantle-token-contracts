// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { MantleOFTUpgradeable } from "contracts/OFT/MantleOFTUpgradeable.sol";
import { MantleOFTAdapterUpgradeable } from "contracts/OFT/MantleOFTAdapterUpgradeable.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract Temp { }

contract MockEndpoint {
    function setDelegate(address _delegate) public { }
}

contract MockToken {
    function decimals() public pure returns (uint8) {
        return 18;
    }
}

contract MantleOFTTest is Test {
    MantleOFTUpgradeable public oft;
    MantleOFTAdapterUpgradeable public oftAdapter;

    address public owner = address(0x123);
    address public lzEndpoint = address(0x456);
    address public token = address(0x789);

    string public constant TOKEN_NAME = "Mantle Token";
    string public constant TOKEN_SYMBOL = "MNT";
    uint8 public constant TOKEN_DECIMALS = 18;

    function setUp() public {
        lzEndpoint = address(new MockEndpoint());
        token = address(new MockToken());
        // Deploy OFT
        MantleOFTUpgradeable oftImpl = new MantleOFTUpgradeable(lzEndpoint);
        address proxy = _deployProxy(keccak256(bytes("MantleOFTProxy")), address(this));
        _initProxy(
            proxy,
            address(oftImpl),
            abi.encodeWithSelector(oftImpl.initialize.selector, TOKEN_NAME, TOKEN_SYMBOL, owner)
        );
        oft = MantleOFTUpgradeable(proxy);

        // Deploy OFT Adapter
        MantleOFTAdapterUpgradeable oftAdapterImpl = new MantleOFTAdapterUpgradeable(token, lzEndpoint);
        proxy = _deployProxy(keccak256(bytes("MantleOFTAdapterProxy")), address(this));
        _initProxy(proxy, address(oftAdapterImpl), abi.encodeWithSelector(oftAdapterImpl.initialize.selector, owner));
        oftAdapter = MantleOFTAdapterUpgradeable(proxy);
    }

    function test_MantleOFTUpgradeable_Constructor() public {
        // Test that constructor properly sets the endpoint
        assertEq(address(oft.endpoint()), lzEndpoint, "LZ endpoint should be set correctly");
    }

    function test_MantleOFTUpgradeable_Initialize() public {
        // Verify token properties
        assertEq(oft.name(), TOKEN_NAME, "Token name should be set correctly");
        assertEq(oft.symbol(), TOKEN_SYMBOL, "Token symbol should be set correctly");
        assertEq(oft.decimals(), TOKEN_DECIMALS, "Token decimals should be 18");
        assertEq(oft.owner(), owner, "Owner should be set correctly");

        // Verify OFT properties
        assertEq(oft.approvalRequired(), false, "Approval should not be required by default");
    }

    function test_MantleOFTUpgradeable_Initialize_RevertIfAlreadyInitialized() public {
        // Try to initialize again - should revert
        vm.expectRevert();
        vm.prank(owner);
        oft.initialize(TOKEN_NAME, TOKEN_SYMBOL, owner);
    }

    function test_MantleOFTAdapterUpgradeable_Constructor() public {
        // Test that constructor properly sets the token and endpoint
        assertEq(oftAdapter.token(), token, "Token should be set correctly");
        assertEq(address(oftAdapter.endpoint()), lzEndpoint, "LZ endpoint should be set correctly");
    }

    function test_MantleOFTAdapterUpgradeable_Initialize() public {
        // Verify ownership
        assertEq(oftAdapter.owner(), owner, "Owner should be set correctly");

        // Verify OFT properties
        assertEq(oftAdapter.approvalRequired(), true, "Approval should be required for adapter");
    }

    function test_MantleOFTAdapterUpgradeable_Initialize_RevertIfAlreadyInitialized() public {
        // Try to initialize again - should revert
        vm.expectRevert();
        vm.prank(owner);
        oftAdapter.initialize(owner);
    }

    function test_MantleOFTUpgradeable_OwnershipTransfer() public {
        address newOwner = address(0x999);

        vm.prank(owner);
        oft.transferOwnership(newOwner);

        assertEq(oft.owner(), newOwner, "Ownership should be transferred");
    }

    function test_MantleOFTAdapterUpgradeable_OwnershipTransfer() public {
        address newOwner = address(0x999);

        vm.prank(owner);
        oftAdapter.transferOwnership(newOwner);

        assertEq(oftAdapter.owner(), newOwner, "Ownership should be transferred");
    }

    function _deployProxy(bytes32 salt, address deployer) internal returns (address) {
        Temp temp = new Temp();
        TransparentUpgradeableProxy proxyContract =
            new TransparentUpgradeableProxy{ salt: salt }(address(temp), deployer, bytes(""));
        return address(proxyContract);
    }

    function _initProxy(address proxy, address impl, bytes memory initData) internal {
        bytes32 slot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        address admin = address(uint160(uint256(vm.load(proxy, slot))));
        ProxyAdmin(admin).upgradeAndCall(ITransparentUpgradeableProxy(proxy), impl, initData);
    }
}
