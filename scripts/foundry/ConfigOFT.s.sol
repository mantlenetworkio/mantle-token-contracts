// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { SetConfigParam } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import { UlnConfig } from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import { ExecutorConfig } from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import { IOAppCore } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppCore.sol";
import { stdToml } from "forge-std/StdToml.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

struct Config {
    address endpoint;
    address oapp;
    uint32 remoteEid;
    address lib;
    uint32 confirmations;
    uint8 reqDvnCount;
    address[] dvns;
}


/// @title LayerZero Send Configuration Script (A → B)
/// @notice Defines and applies ULN (DVN) + Executor configs for cross‑chain messages sent from Chain A to Chain B via LayerZero Endpoint V2.
contract ConfigOFT is Script {
    using stdToml for string;

    uint32 constant EXECUTOR_CONFIG_TYPE = 1;
    uint32 constant ULN_CONFIG_TYPE = 2;

    string constant TOML_PATH = "scripts/foundry/oft.config.toml";
    string public toml;

    function setUp() public {
        toml = vm.readFile(TOML_PATH);
    }

    /// @dev use: FOUNDRY_PROFILE=sepolia forge script scripts/foundry/ConfigOFT.s.sol --sig "setSendConfig(string,string)" eth bsc
    function setSendConfig(string memory from, string memory to) external {
        _sanityCheck(true, from, to);
        _setConfig(_isMainnet(), true, from, to);
    }

    /// @dev use: FOUNDRY_PROFILE=bsc-testnet forge script scripts/foundry/ConfigOFT.s.sol --sig "setReceiveConfig(string,string)" eth bsc
    function setReceiveConfig(string memory from, string memory to) external {
        _sanityCheck(false, from, to);
        _setConfig(_isMainnet(), false, from, to);
    }


    function _setConfig(bool mainnet, bool send, string memory from, string memory to) internal {
        uint256 callerPrivateKey = vm.envUint("PRIVATE_KEY");
        address callAddress = vm.addr(callerPrivateKey);
        console.log("callAddress", callAddress);
        console.log("configuring from", from, "to", to);

        string memory key = string.concat(".", mainnet ? "mainnet" : "testnet", ".", from, ".", to, ".", send ? "send" : "receive");
        Config memory config = abi.decode(toml.parseRaw(key), (Config));

        address endpoint = config.endpoint;
        address oapp     = config.oapp;
        uint32 eid       = config.remoteEid;
        address lib      = config.lib;

        console.log("endpoint", endpoint);
        console.log("oapp", oapp);
        console.log("eid", eid);
        console.log("lib", lib);

        /// @notice ULNConfig defines security parameters (DVNs + confirmation threshold) for A → B
        /// @notice Send config requests these settings to be applied to the DVNs and Executor for messages sent from A to B
        /// @dev 0 values will be interpretted as defaults, so to apply NIL settings, use:
        /// @dev uint8 internal constant NIL_DVN_COUNT = type(uint8).max;
        /// @dev uint64 internal constant NIL_CONFIRMATIONS = type(uint64).max;
        UlnConfig memory uln = UlnConfig({
            confirmations:        config.confirmations,                                     // minimum block confirmations required on A before sending to B
            requiredDVNCount:     config.reqDvnCount,                                       // number of DVNs required
            optionalDVNCount:     type(uint8).max,                                          // optional DVNs count, uint8
            optionalDVNThreshold: 0,                                                        // optional DVN threshold
            requiredDVNs:        config.dvns,                                               // sorted list of required DVN addresses
            optionalDVNs:        new address[](0)                                           // sorted list of optional DVNs
        });

        bytes memory encodedUln  = abi.encode(uln);

        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam(eid, ULN_CONFIG_TYPE, encodedUln);

        vm.startBroadcast(callerPrivateKey);
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, lib, params); // Set config for messages sent from A to B
        if (send && toml.readBool(".set_peer")) {
            console.log("setting peer for", from, "to", to);
            string memory peerKey = string.concat(".", mainnet ? "mainnet" : "testnet", ".", from, ".", to, ".", "receive.b_oapp");
            address peer = abi.decode(toml.parseRaw(peerKey), (address));
            console.log("peer", peer);
            IOAppCore(oapp).setPeer(eid, bytes32(uint256(uint160(peer))));
        }
        vm.stopBroadcast();

        _getConfig(endpoint, oapp, lib, eid);
    }

    function _getConfig(address _endpoint,address _oapp, address _lib, uint32 _remoteEid) internal view {
        ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(_endpoint);
        bytes memory receiveUlnConfigBytes = endpoint.getConfig(_oapp, _lib, _remoteEid, ULN_CONFIG_TYPE);

        UlnConfig memory config = abi.decode(receiveUlnConfigBytes, (UlnConfig));
        console.log("get config:");
        console.log("confirmations: %d",config.confirmations);
        console.log("requiredDVNCount: %d",config.requiredDVNCount);
        console.log("optionalDVNCount: %d",config.optionalDVNCount);
        console.log("optionalDVNThreshold: %d",config.optionalDVNThreshold);
        console.log("requiredDVNs:");
        for (uint256 i; i < config.requiredDVNs.length; i++) {
            console.logAddress(config.requiredDVNs[i]);
        }
        console.log("optionalDVNs:");
        for (uint256 i; i < config.optionalDVNs.length; i++) {
            console.logAddress(config.optionalDVNs[i]);
        }
    }

    function _isMainnet() internal view returns (bool) {
        return block.chainid == 1 || block.chainid == 56 || block.chainid == 999;
    }

    function _sanityCheck(bool setSend,string memory from, string memory to) internal view {
        if (keccak256(bytes(from)) == keccak256(bytes(to))) {
            revert("from and to cannot be the same");
        }
        string memory targetChain = setSend ? from : to;
        if (bytes32(bytes(targetChain)) == bytes32(bytes("eth"))) {
            require(block.chainid == 1 || block.chainid == 11155111, "current chain is not ethereum");
        } else if (bytes32(bytes(targetChain)) == bytes32(bytes("bsc"))) {
            require(block.chainid == 56 || block.chainid == 97, "current chain is not bsc");
        } else if (bytes32(bytes(targetChain)) == bytes32(bytes("hyper"))) {
            require(block.chainid == 999 || block.chainid == 998, "current chain is not hyper");
        } else {
            revert("unsupported chain, either eth | bsc | hyper");
        }
    }
}