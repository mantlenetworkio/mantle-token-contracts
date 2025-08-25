// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OFTUpgradeable } from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTUpgradeable.sol";

/// @title MantleOFT
/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract MantleOFTHyperEVMUpgradeable is OFTUpgradeable {
    /// keccak256("HyperCore deployer")
    bytes32 private constant HyperCoreDeployerSlot = 0x8c306a6a12fff1951878e8621be6674add1102cd359dd968efbbe797629ef84f;

    constructor(address _lzEndpoint) OFTUpgradeable(_lzEndpoint) {
        require(_lzEndpoint != address(0), "lzEndpoint is required");
        _disableInitializers();
    }

    function initialize(string memory _name, string memory _symbol, address _owner) public initializer {
        __OFT_init(_name, _symbol, _owner);
        __Ownable_init(_owner);
        __Context_init();
    }

    function setHyperCoreDeployer(address _hyperCoreDeployer) public onlyOwner {
        require(_hyperCoreDeployer != address(0), "hyperCoreDeployer set to zero address");
        assembly {
            sstore(HyperCoreDeployerSlot, _hyperCoreDeployer)
        }
    }
}
