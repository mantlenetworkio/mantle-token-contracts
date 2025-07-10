// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import {
    ILayerZeroEndpointV2,
    Origin
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract DebugOFT is Script {
    function lzReceive() public {
        uint256 callerPrivateKey = vm.envUint("PRIVATE_KEY");
        address callAddress = vm.addr(callerPrivateKey);
        console.log("callAddress", callAddress);

        address endpoint = vm.envAddress("LZ_ENDPOINT");
        console.log("endpoint", endpoint);

        vm.startBroadcast(callerPrivateKey);

        ILayerZeroEndpointV2(endpoint).lzReceive(
            Origin({
                srcEid: 40102,
                sender: bytes32(0x000000000000000000000000cdb3d2dc427a5bc9af54a9c2ed2f5950619184bf),
                nonce: 4
            }),
            0x0A47fcA335c9879014D3150b2478aFb53c8eE5aF,
            bytes32(0x7b73308b6a70389b3f47e0a70d8547c5cbbe4371ac5949ba8a476750e73db395),
            hex"000000000000000000000000be5a5cdc00ed5eecd7fe323e870902751e4da9c300000000000f4240",
            bytes("")
        );
    }
}
