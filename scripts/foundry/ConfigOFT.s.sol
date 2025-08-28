// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "./BaseScript.s.sol";
import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { SetConfigParam } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import { UlnConfig } from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import { ExecutorConfig } from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import { IOAppCore } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppCore.sol";
import { IOAppOptionsType3 } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import { EnforcedOptionParam } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OAppOptionsType3.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { MantleOFTHyperEVMUpgradeable } from "contracts/OFT/MantleOFTHyperEVMUpgradeable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title LayerZero Send Configuration Script (A → B)
/// @notice Defines and applies ULN (DVN) + Executor configs for cross‑chain messages sent from Chain A to Chain B via LayerZero Endpoint V2.
contract ConfigOFT is BaseScript {
    using stdToml for string;
    using OptionsBuilder for bytes;

    uint32 constant EXECUTOR_CONFIG_TYPE = 1;
    uint32 constant ULN_CONFIG_TYPE = 2;

    address public endpoint;
    address public oft;
    address public sendLib;
    address public receiveLib;
    mapping(string => address) public dvnMap;

    function setUp() public override {
        super.setUp();

        string memory network = networkName;
        endpoint = config.readAddress(string.concat(".lz.", network, ".endpoint"));
        oft = _readDeployment(string.concat(".oft.", network, ".", networkKey));
        sendLib = config.readAddress(string.concat(".lz.", network, ".send_lib"));
        receiveLib = config.readAddress(string.concat(".lz.", network, ".receive_lib"));
        string[] memory dvnsName = config.readStringArray(string.concat(".lz.", network, ".dvns_name"));
        address[] memory dvnsAddr = config.readAddressArray(string.concat(".lz.", network, ".dvns_addr"));
        for (uint256 i; i < dvnsName.length; i++) {
            dvnMap[dvnsName[i]] = dvnsAddr[i];
        }

        require(endpoint != address(0), "Endpoint is not set");
        require(oft != address(0), "OFT is not set");
        require(sendLib != address(0), "Send lib is not set");
        require(receiveLib != address(0), "Receive lib is not set");
        require(dvnsName.length > 0, "DVNs are not set");
        require(dvnsAddr.length > 0, "DVNs are not set");
        require(dvnsName.length == dvnsAddr.length, "DVNs name and address length mismatch");
    }

    /// @dev use: FOUNDRY_PROFILE=sepolia forge script scripts/foundry/ConfigOFT.s.sol --sig "setSendConfig(string,string)" eth bsc
    function setSendConfig(string memory from, string memory to) external {
        _sanityCheck(true, from, to);
        _setConfig(true, from, to);
    }

    /// @dev use: FOUNDRY_PROFILE=bsc-testnet forge script scripts/foundry/ConfigOFT.s.sol --sig "setReceiveConfig(string,string)" eth bsc
    function setReceiveConfig(string memory from, string memory to) external {
        _sanityCheck(false, from, to);
        _setConfig(false, from, to);
    }

    /// @dev use: FOUNDRY_PROFILE=sepolia forge script scripts/foundry/ConfigOFT.s.sol --sig "setEnforcedOption(string)" eth
    function setEnforcedOption(string memory from) external {
        _sanityCheck(true, from, "");
        _setEnforcedOption(from);
    }

    /// @dev use: FOUNDRY_PROFILE=hyper-testnet forge script scripts/foundry/ConfigOFT.s.sol --sig "setHyperCoreDeployer()"
    function setHyperCoreDeployer() external {
        require(bytes32(bytes(networkName)) == bytes32(bytes("hyper")), "This function is only available on HyperEVM");
        address hyperCoreDeployer = config.readAddress(string.concat(".config.hypercore_deployer"));
        console.log("setting hypercore deployer");
        console.log("oft", oft);
        console.log("hypercore deployer", hyperCoreDeployer);
        bytes32 slot = keccak256(bytes("HyperCore deployer"));
        address currentHyperCoreDeployer = address(uint160(uint256(vm.load(oft, slot))));
        console.log("current hypercore deployer", currentHyperCoreDeployer);
        require(currentHyperCoreDeployer != hyperCoreDeployer, "HyperCore deployer is already set");
        _startBroadcast();
        MantleOFTHyperEVMUpgradeable(oft).setHyperCoreDeployer(hyperCoreDeployer);
        _stopBroadcast();
        require(vm.load(oft, slot) == bytes32(uint256(uint160(hyperCoreDeployer))), "HyperCore deployer mismatch");
    }

    /// @dev use: FOUNDRY_PROFILE=sepolia forge script scripts/foundry/ConfigOFT.s.sol --sig "transferOwnership(address)" 0xD3E476239EC4Bd04daf76A4f8BA4E56139a41b5c
    function transferOwnership(address newOwner) external {
        require(newOwner != address(0), "newOwner cannot be the zero address");
        require(newOwner != oft, "newOwner cannot be the same as oft");

        address currentOwner = Ownable(oft).owner();
        console.log("current owner", currentOwner);
        console.log("new owner", newOwner);
        require(currentOwner != newOwner, "newOwner cannot be the same as current owner");

        _startBroadcast();
        Ownable(oft).transferOwnership(newOwner);
        _stopBroadcast();

        require(Ownable(oft).owner() == newOwner, "Ownership transfer failed");
    }

    /// @dev use: FOUNDRY_PROFILE=sepolia forge script scripts/foundry/ConfigOFT.s.sol --sig "transferProxyAdminOwnership(address)" <NEW_OWNER>
    function transferProxyAdminOwnership(address newOwner) external {
        require(newOwner != address(0), "newOwner cannot be the zero address");
        require(newOwner != oft, "newOwner cannot be the same as oft");
        address proxyAdmin = _proxyAdmin(oft);
        console.log("proxyAdmin", proxyAdmin);
        require(proxyAdmin != address(0), "proxyAdmin is not set. Is it a proxy?");
        require(proxyAdmin != newOwner, "newOwner cannot be the same as proxyAdmin");

        address currentOwner = Ownable(proxyAdmin).owner();
        console.log("current owner", currentOwner);
        console.log("newOwner", newOwner);
        require(currentOwner != newOwner, "newOwner cannot be the same as current owner");

        _startBroadcast();
        Ownable(proxyAdmin).transferOwnership(newOwner);
        _stopBroadcast();
        require(Ownable(proxyAdmin).owner() == newOwner, "Ownership transfer failed");
    }

    /// @dev use: FOUNDRY_PROFILE=sepolia forge script scripts/foundry/ConfigOFT.s.sol --sig "getConfig(string,bool)" eth true
    function getConfig(string memory remoteChain, bool send) external view {
        require(
            bytes32(bytes(remoteChain)) != bytes32(bytes(networkName)), "remoteChain cannot be the same as networkName"
        );
        string memory direction = send
            ? string.concat(networkName, " \u2192 ", remoteChain)
            : string.concat(remoteChain, " \u2192 ", networkName);
        console.log("get config", direction, send ? "send" : "receive");
        _getConfig(
            endpoint,
            oft,
            send ? sendLib : receiveLib,
            uint32(config.readUint(string.concat(".lz.", remoteChain, ".eid")))
        );
    }

    function _setConfig(bool send, string memory from, string memory to) internal {
        console.log("configuring from", from, "to", to);

        string memory key = string.concat(".config.", from, ".", to, send ? ".send" : ".receive");
        uint32 confirmations = uint32(config.readUint(string.concat(key, ".confirmations")));
        uint8 reqDvnCount = uint8(config.readUint(string.concat(key, ".req_dvn_count")));
        require(reqDvnCount > 0, "req_dvn_count must be greater than 0");
        string[] memory dvnsName = config.readStringArray(string.concat(key, ".dvns"));
        require(dvnsName.length >= reqDvnCount, "dvns count is less than required");
        address[] memory dvns = new address[](dvnsName.length);
        for (uint256 i; i < dvnsName.length; i++) {
            dvns[i] = dvnMap[dvnsName[i]];
            if (dvns[i] == address(0)) {
                revert(string.concat("dvn ", dvnsName[i], " not found"));
            }
        }

        // Sort dvns in ascending order
        _sortAddresses(dvns);

        uint32 eid = uint32(config.readUint(string.concat(".lz.", send ? to : from, ".eid")));
        address lib = send ? sendLib : receiveLib;

        console.log("endpoint", endpoint);
        console.log("oapp", oft);
        console.log("remote eid", eid);
        console.log(send ? "send" : "receive", "lib", lib);

        /// @notice ULNConfig defines security parameters (DVNs + confirmation threshold) for A → B
        /// @notice Send config requests these settings to be applied to the DVNs and Executor for messages sent from A to B
        /// @dev 0 values will be interpretted as defaults, so to apply NIL settings, use:
        /// @dev uint8 internal constant NIL_DVN_COUNT = type(uint8).max;
        /// @dev uint64 internal constant NIL_CONFIRMATIONS = type(uint64).max;
        UlnConfig memory uln = UlnConfig({
            confirmations: confirmations, // minimum block confirmations required on A before sending to B
            requiredDVNCount: reqDvnCount, // number of DVNs required
            optionalDVNCount: type(uint8).max, // optional DVNs count, uint8
            optionalDVNThreshold: 0, // optional DVN threshold
            requiredDVNs: dvns, // sorted list of required DVN addresses
            optionalDVNs: new address[](0) // sorted list of optional DVNs
         });

        bytes memory encodedUln = abi.encode(uln);

        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam(eid, ULN_CONFIG_TYPE, encodedUln);

        _startBroadcast();

        ILayerZeroEndpointV2(endpoint).setConfig(oft, lib, params); // Set config for messages sent from A to B

        if (send && config.readBool(".config.set_peer")) {
            console.log("setting peer for", from, "to", to);
            address peer = _readDeployment(string.concat(".oft.", to, ".", networkKey));
            console.log("peer", eid, peer);
            IOAppCore(oft).setPeer(eid, bytes32(uint256(uint160(peer))));
        }

        _stopBroadcast();

        _getConfig(endpoint, oft, lib, eid);
    }

    function _setEnforcedOption(string memory from) internal {
        console.log("setting enforced options for", from);

        string memory key = string.concat(".config.", from, ".enforced_options");
        console.log("oft", oft);
        string[] memory dsts = config.readStringArray(string.concat(key, ".dsts"));
        uint256[] memory dstEids = new uint256[](dsts.length);
        uint256[] memory receiveGasOptions = config.readUintArray(string.concat(key, ".lzReceive_gas_options"));
        require(dsts.length == receiveGasOptions.length, "dsts and receiveGasOptions must have the same length");

        for (uint256 i; i < dsts.length; i++) {
            dstEids[i] = uint256(config.readUint(string.concat(".lz.", dsts[i], ".eid")));
            console.log("dst", dsts[i], dstEids[i]);
            console.log("receiveGasOptions", receiveGasOptions[i]);
        }

        // Message type (should match your contract's constant)
        uint16 SEND = 1; // Message type for sendString function
        // uint16 SEND_AND_CALL = 2; // Message type for sendStringAndCall function

        // Create enforced options array
        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](dstEids.length);
        for (uint256 i; i < dstEids.length; i++) {
            bytes memory options =
                OptionsBuilder.newOptions().addExecutorLzReceiveOption(uint128(receiveGasOptions[i]), 0);
            enforcedOptions[i] = EnforcedOptionParam({ eid: uint32(dstEids[i]), msgType: SEND, options: options });
        }

        _startBroadcast();

        // Set enforced options on the OApp
        IOAppOptionsType3(oft).setEnforcedOptions(enforcedOptions);

        _stopBroadcast();

        console.log("Enforced options set successfully!");
    }

    function _getConfig(address _endpoint, address _oapp, address _lib, uint32 _remoteEid) internal view {
        bytes memory receiveUlnConfigBytes =
            ILayerZeroEndpointV2(_endpoint).getConfig(_oapp, _lib, _remoteEid, ULN_CONFIG_TYPE);

        UlnConfig memory config = abi.decode(receiveUlnConfigBytes, (UlnConfig));
        console.log("get config:");
        console.log("confirmations: %d", config.confirmations);
        console.log("requiredDVNCount: %d", config.requiredDVNCount);
        console.log("optionalDVNCount: %d", config.optionalDVNCount);
        console.log("optionalDVNThreshold: %d", config.optionalDVNThreshold);
        console.log("requiredDVNs:");
        for (uint256 i; i < config.requiredDVNs.length; i++) {
            console.logAddress(config.requiredDVNs[i]);
        }
        console.log("optionalDVNs:");
        for (uint256 i; i < config.optionalDVNs.length; i++) {
            console.logAddress(config.optionalDVNs[i]);
        }
    }

    function _sanityCheck(bool setSend, string memory from, string memory to) internal view {
        if (keccak256(bytes(from)) == keccak256(bytes(to))) {
            revert("from and to cannot be the same");
        }
        string memory targetChain = setSend ? from : to;
        if (bytes32(bytes(targetChain)) != bytes32(bytes(networkName))) {
            string memory revertReason = string.concat("target chain ", targetChain, " is not ", networkName);
            revert(revertReason);
        }
    }

    /// @dev Sorts an array of addresses in ascending order using bubble sort
    function _sortAddresses(address[] memory addresses) internal pure {
        uint256 length = addresses.length;
        for (uint256 i = 0; i < length - 1; i++) {
            for (uint256 j = 0; j < length - i - 1; j++) {
                if (addresses[j] > addresses[j + 1]) {
                    // Swap addresses
                    address temp = addresses[j];
                    addresses[j] = addresses[j + 1];
                    addresses[j + 1] = temp;
                }
            }
        }
    }
}
