// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { IOFT, SendParam } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { MessagingFee } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SendOFT is Script {
    using OptionsBuilder for bytes;

    address public constant MAINNET_MNT_ADDRESS = 0x3c3a81e81dc49A522A592e7622A7E711c06bf354;
    address public constant SEPOLIA_MNT_ADDRESS = 0x65e37B558F64E2Be5768DB46DF22F93d85741A9E;

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    /// @dev use:FOUNDRY_PROFILE=sepolia forge script scripts/foundry/SendOFT.s.sol --sig "sendOFT(address,uint32,address,uint256)" 0x0A47fcA335c9879014D3150b2478aFb53c8eE5aF 40102 0xD3E476239EC4Bd04daf76A4f8BA4E56139a41b5c 100000000000000000000
    function sendOFT(address oftAddress, uint32 dstEid, address toAddress, uint256 tokensToSend) external {
        uint256 callerPrivateKey = vm.envUint("PRIVATE_KEY");
        address callerAddress = vm.addr(callerPrivateKey);
        console.log("callerAddress", callerAddress);

        vm.startBroadcast(callerPrivateKey);

        // Approve the OFT contract to spend the tokens if needed
        if (block.chainid == 11155111) {
            uint256 allowance = IERC20(SEPOLIA_MNT_ADDRESS).allowance(callerAddress, oftAddress);
            if (allowance < tokensToSend) {
                IERC20(SEPOLIA_MNT_ADDRESS).approve(oftAddress, tokensToSend);
            }
        } else if (block.chainid == 1) {
            uint256 allowance = IERC20(MAINNET_MNT_ADDRESS).allowance(callerAddress, oftAddress);
            if (allowance < tokensToSend) {
                IERC20(MAINNET_MNT_ADDRESS).approve(oftAddress, tokensToSend);
            }
        }

        IOFT oft = IOFT(oftAddress);

        // Build send parameters
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(65000, 0);
        SendParam memory sendParam = SendParam({
            dstEid: dstEid,
            to: addressToBytes32(toAddress),
            amountLD: tokensToSend,
            minAmountLD: tokensToSend * 95 / 100, // 5% slippage tolerance
            extraOptions: extraOptions,
            composeMsg: "",
            oftCmd: ""
        });

        // Get fee quote
        MessagingFee memory fee = oft.quoteSend(sendParam, false);

        console.log("Sending tokens...");
        console.log("Fee amount:", fee.nativeFee);

        // Send tokens
        oft.send{value: fee.nativeFee}(sendParam, fee, msg.sender);

        vm.stopBroadcast();
    }
}