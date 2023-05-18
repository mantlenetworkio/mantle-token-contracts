// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title   Contract to convert BIT (BITDAO) tokens to MNT (Mantle) tokens.
 *
 * @notice  Enable BIT token holders to convert their BIT tokens into MNT tokens. 
 *
 * @dev     Provide the following functionalities:
 *          1. Deposit MNT (Mantle) tokens into this contract.
 *          2. Convert BIT tokens to MNT tokens using a pre-defined convertion rate 1 BIT = 3.14 MNT.
 *          3. Enable/disable conversion.
 */
contract MantleTokenMigrator is Ownable {
    using SafeERC20 for IERC20;

    /// @notice The amount that can be can be migrated - denominator
    uint256 public constant CONVERSION_DENOMINATOR = 100;
    /// @notice The amount that can be can be migrated - numerator
    uint256 public constant CONVERSION_NUMERATOR = 314;

    /// Events
    event Deposit(address from, uint256 amount);

    /* ========== MIGRATION ========== */
    /* ========== STATE VARIABLES ========== */

    IERC20 public immutable bit;
    IERC20 public mantle;

    bool public enabled;

    uint256 public bitAmountMigrated;
    uint256 public mantleAmountMigrated;

    constructor(address _bit) {
        require(_bit != address(0), "Zero address: bit");
        bit = IERC20(_bit);
    }

    /* ========== MIGRATION ========== */

    // migrate bit to mantle
    function migrate(uint256 _bitAmount) external {
        require(enabled, "Migration: migrate enabled");

        uint256 mantleAmount = (_bitAmount * CONVERSION_NUMERATOR) / CONVERSION_DENOMINATOR;

        bit.safeTransferFrom(msg.sender, address(this), _bitAmount);

        bitAmountMigrated = bitAmountMigrated + _bitAmount;
        mantleAmountMigrated = mantleAmountMigrated + mantleAmount;
        uint256 mantleAmountBalance = IERC20(mantle).balanceOf(address(this));
        require(mantleAmount <= mantleAmountBalance, "Insufficient: not sufficient mantle");

        mantle.safeTransfer(msg.sender, mantleAmount);
    }

    // deposit mantle here
    function deposit(uint256 _amount) external {
        require(address(mantle) != address(0), "Zero address: mantle");
        IERC20(mantle).safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, _amount);
    }

    /* ========== OWNABLE ========== */

    // enable migrations
    function unpause() external onlyOwner {
        enabled = true;
    }

    // disable migrations
    function pause() external onlyOwner {
        enabled = false;
    }

    // set mantle address
    function setMantle(address _mantle) external onlyOwner {
        require(address(mantle) == address(0), "Already set, only can be set once");
        require(_mantle != address(0), "Zero address: mantle");

        mantle = IERC20(_mantle);
    }

    // function to allow owner to withdraw funds(tokens except bit) sent directly to contract
    function withdrawToken(address tokenAddress, uint256 amount, address recipient) external onlyOwner {
        require(tokenAddress != address(0), "Token address cannot be 0x0");
        require(tokenAddress != address(bit), "Cannot withdraw: bit");
        require(amount > 0, "Withdraw value must be greater than 0");
        if (recipient == address(0)) {
            recipient = msg.sender; // if no address is specified the value will will be withdrawn to Owner
        }

        IERC20 tokenContract = IERC20(tokenAddress);
        uint256 contractBalance = tokenContract.balanceOf(address(this));
        if (amount > contractBalance) {
            amount = contractBalance; // set the withdrawal amount equal to balance within the account.
        }

        // transfer the token from address of this contract
        tokenContract.safeTransfer(recipient, amount);
    }
}
