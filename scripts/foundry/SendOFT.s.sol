// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "./BaseScript.s.sol";
import { IOFT, SendParam } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { MessagingFee } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SendOFT is BaseScript {
    using stdToml for string;
    using OptionsBuilder for bytes;

    address public oft;
    address public mnt;
    address public composer;

    uint256 public constant APPROVE_AMOUNT = type(uint256).max;

    function setUp() public override {
        super.setUp();

        oft = _readDeployment(string.concat(".oft.", networkName, ".", networkKey));
        composer = _readDeployment(string.concat(".hyperliquid_composer.", networkKey));
        mnt = config.readAddress(string.concat(".mnt.", networkKey));

        require(oft != address(0), "OFT is not set");
        require(mnt != address(0), "MNT is not set");
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    /// @dev use:FOUNDRY_PROFILE=sepolia forge script scripts/foundry/SendOFT.s.sol --sig "sendOFTWithComposer(string,address,uint256)" hyper 0xD3E476239EC4Bd04daf76A4f8BA4E56139a41b5c 1
    function sendOFTWithComposer(string memory toChain, address toAddress, uint256 amtWithoutDecimals) external {
        require(bytes32(bytes(toChain)) != bytes32(bytes(networkName)), "Cannot send to the same chain");
        require(composer != address(0), "Composer is not set");

        address receiver = toAddress;
        bytes memory composeMsg;
        if (bytes32(bytes(toChain)) == bytes32(bytes("hyper"))) {
            receiver = composer;
            composeMsg = abi.encode(toAddress);
        }
        uint256 amount = amtWithoutDecimals * 10 ** 18;
        _sendOFT(toChain, receiver, amount, composeMsg);
    }

    /// @dev use:FOUNDRY_PROFILE=sepolia forge script scripts/foundry/SendOFT.s.sol --sig "sendOFTWithComposerAndDecimals(string,address,uint256)" hyper 0xD3E476239EC4Bd04daf76A4f8BA4E56139a41b5c 100000000000000000000
    function sendOFTWithComposerAndDecimals(string memory toChain, address toAddress, uint256 amount) external {
        require(bytes32(bytes(toChain)) != bytes32(bytes(networkName)), "Cannot send to the same chain");
        require(composer != address(0), "Composer is not set");

        address receiver = toAddress;
        bytes memory composeMsg;
        if (bytes32(bytes(toChain)) == bytes32(bytes("hyper"))) {
            receiver = composer;
            composeMsg = abi.encode(toAddress);
        }
        _sendOFT(toChain, receiver, amount, composeMsg);
    }

    /// @dev use:FOUNDRY_PROFILE=sepolia forge script scripts/foundry/SendOFT.s.sol --sig "sendOFT(string,address,uint256)" bsc 0xD3E476239EC4Bd04daf76A4f8BA4E56139a41b5c 1
    function sendOFT(string memory toChain, address toAddress, uint256 amtWithoutDecimals) external {
        require(bytes32(bytes(toChain)) != bytes32(bytes(networkName)), "Cannot send to the same chain");

        uint256 amount = amtWithoutDecimals * 10 ** 18;
        _sendOFT(toChain, toAddress, amount, "");
    }

    /// @dev use:FOUNDRY_PROFILE=sepolia forge script scripts/foundry/SendOFT.s.sol --sig "sendOFTWithDecimals(string,address,uint256)" bsc 0xD3E476239EC4Bd04daf76A4f8BA4E56139a41b5c 100000000000000000000
    function sendOFTWithDecimals(string memory toChain, address toAddress, uint256 amount) external {
        require(bytes32(bytes(toChain)) != bytes32(bytes(networkName)), "Cannot send to the same chain");
        _sendOFT(toChain, toAddress, amount, "");
    }

    /// @dev use:FOUNDRY_PROFILE=sepolia forge script scripts/foundry/SendOFT.s.sol --sig "sendOFTWithComposerRefund(string,address,uint256)" hyper 0x0000000000000000000000000000000000000001 1
    function sendOFTWithComposerRefund(string memory toChain, address toAddress, uint256 amtWithoutDecimals) external {
        require(bytes32(bytes(toChain)) != bytes32(bytes(networkName)), "Cannot send to the same chain");
        require(bytes32(bytes(toChain)) == bytes32(bytes("hyper")), "Only HyperEVM is supported");
        require(bytes32(bytes(networkKey)) == bytes32(bytes("testnet")), "Only HyperEVM testnet is supported");
        require(composer != address(0), "Composer is not set");

        address receiver = composer;
        // construct a meaningless wrong compose message to refund the sender
        bytes memory composeMsg = abi.encodePacked(keccak256(abi.encode(toAddress)));
        uint256 amount = amtWithoutDecimals * 10 ** 18;
        _sendOFT(toChain, receiver, amount, composeMsg);
    }

    function _sendOFT(string memory toChain, address toAddress, uint256 amount, bytes memory composeMsg) internal {
        uint32 dstEid = uint32(config.readUint(string.concat(".lz.", toChain, ".", networkKey, ".eid")));

        console.log("Sending tokens to", toChain, "on EID", dstEid);
        console.log("Amount:", amount);
        console.log("To address:", toAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Approve the OFT contract to spend the tokens if needed
        if (bytes32(bytes(networkName)) == bytes32(bytes("eth"))) {
            uint256 allowance = IERC20(mnt).allowance(deployerAddress, oft);
            if (allowance < amount) {
                IERC20(mnt).approve(oft, APPROVE_AMOUNT);
            }
        }

        // Build send parameters
        bytes memory extraOptions;
        if (composeMsg.length > 0) {
            require(bytes32(bytes(toChain)) == bytes32(bytes("hyper")), "composeMsg is only available for HyperEVM");
            extraOptions = OptionsBuilder.newOptions().addExecutorLzComposeOption(0, 100000, 0);
        }

        SendParam memory sendParam = SendParam({
            dstEid: dstEid,
            to: addressToBytes32(toAddress),
            amountLD: amount,
            minAmountLD: amount * 95 / 100, // 5% slippage tolerance
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: ""
        });

        // Get fee quote
        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);

        console.log("Sending tokens...");
        console.log("Fee amount:", fee.nativeFee);

        // Send tokens
        IOFT(oft).send{ value: fee.nativeFee }(sendParam, fee, msg.sender);

        vm.stopBroadcast();
    }
}
