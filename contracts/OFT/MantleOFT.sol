// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title MantleOFT
/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract MantleOFT is OFT {
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _owner
    ) OFT(_name, _symbol, _lzEndpoint, _owner) Ownable(_owner) {}
} 