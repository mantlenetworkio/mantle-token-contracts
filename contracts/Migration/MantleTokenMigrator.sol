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

    /**
     *  The conversion ratio is 3.14 = 314/100 (~Pi) and is specified by a denominator/numerator. 
     */
    /** Denominator of conversion ratio. */ 
    uint256 public constant CONVERSION_DENOMINATOR = 100;
    /** Numerator of conversion ratio. */ 
    uint256 public constant CONVERSION_NUMERATOR = 314;

    /// Events
    event Deposit(address from, uint256 amount);

    /* ========== MIGRATION ========== */
    /* ========== STATE VARIABLES ========== */

    /** The ERC20 BIT contract. Can only be set once. */
    IERC20 public immutable bit;
    /** The ERC-20 MNT contract. */
    IERC20 public mantle;

    /** Whether conversion is enabled or not. */
    bool public enabled;

    /**  Amount of BIT tokens converted by BIT token holders so far. */
    uint256 public bitAmountMigrated;
    /** Amount of MNT tokens credited to BIT token holders who have converted BIT tokens. */
    uint256 public mantleAmountMigrated;

    /**
     *  Set the address of the BIT token ERC-20 contract.
     *
     *  @dev    An arbitrary address can be passed as argument and will be
     *          cast to en ERC20 contract. 
     *
     *  @param  _bit    The address of the ERC-20 BIT token contract.
     * 
     *  Requirements:
     *      - `_bit` cannot be the zero address.
     */
    constructor(address _bit) {
        require(_bit != address(0), "Zero address: bit");
        bit = IERC20(_bit);
    }

    /**
     *  Enable users to convert BIT token to MNT tokens.
     *
     *  @dev    The token conversion comprises the following steps:
     *          1.  transfer _bitAmount of BIT (`bit` ERC-20 token contract ) from `msg.sender` to `this`.
     *          2.  transfer the corresponding amount of MNT (`mantle` ERC-20 token contract) from `this` to `msg.sender`.
     *          As we are using a decimal conversion ratio, a small amount of MNT may be lost due to rounding. 
     *          For instance, converting 101 BIT results to MNT should yield 317.14 MNT which with interger division
     *          is rounded down to 317. The amount lost a conversion is negilgible and always less than 1**-18 MNT.
     *
     *  @param  _bitAmount  The amount of BIT tokens to convert.
     *
     *  Requirements:
     *      - conversion must be enabled
     *      - the balance of `this` contract must be larger or equal than the amount of MNT to transfer.
     *
     */
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

    /**
     *  Deposit some MNT tokens.
     *  @todo   Is it necessary? 
     */
    function deposit(uint256 _amount) external {
        require(address(mantle) != address(0), "Zero address: mantle");
        IERC20(mantle).safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, _amount);
    }

    /**
     *  Enable conversion for users.
     *
     *  Requirements:
     *      - can only be set by owner.
     */
    function unpause() external onlyOwner {
        enabled = true;
    }

    /**
     *  Disable conversion for users.
     *
     *  Requirements:
     *      - can only be set by owner.
     */    function pause() external onlyOwner {
        enabled = false;
    }

    // set mantle address
    /**
     *  Set the MNT ERC-20 mantle address. 
     *  @todo   Is it necessary? Why isn't it immutable? 
     */
    function setMantle(address _mantle) external onlyOwner {
        require(address(mantle) == address(0), "Already set, only can be set once");
        require(_mantle != address(0), "Zero address: mantle");

        mantle = IERC20(_mantle);
    }

    // function to allow owner to withdraw funds(tokens except bit) sent directly to contract
    /**
     *  ??
     */
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
