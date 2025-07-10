// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OFTAdapterUpgradeable } from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";

/// @title MantleOFTAdapter
/// @notice OFTAdapter uses a deployed ERC-20 token and SafeERC20 to interact with the OFTCore contract.
contract MantleOFTAdapterUpgradeable is OFTAdapterUpgradeable {
    constructor(
        address _token,
        address _lzEndpoint
    ) OFTAdapterUpgradeable(_token, _lzEndpoint) {
        _disableInitializers();
    }

    function initialize(address _owner) public initializer {
        __OFTAdapter_init(_owner);
        __Ownable_init(_owner);
    }
}