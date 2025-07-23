// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OFTUpgradeable } from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTUpgradeable.sol";

/// @title MantleOFT
/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract MantleOFTUpgradeable is OFTUpgradeable {
    constructor(address _lzEndpoint) OFTUpgradeable(_lzEndpoint) {
        require(_lzEndpoint != address(0), "lzEndpoint is required");
        _disableInitializers();
    }

    function initialize(string memory _name, string memory _symbol, address _owner) public initializer {
        __OFT_init(_name, _symbol, _owner);
        __Ownable_init(_owner);
        __Context_init();
    }
}
