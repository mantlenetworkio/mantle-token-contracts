// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MantleTokenMigrator is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice The amount that can be can be migrated - denominator
    uint256 public constant CONVERATION_DENOMINATOR = 100;
    /// @notice The amount that can be can be migrated - numerator
    uint256 public constant CONVERATION_NUMERATOR = 314;

    /* ========== MIGRATION ========== */
    /* ========== STATE VARIABLES ========== */

    IERC20 public immutable bit;
    IERC20 public mantle;

    bool public shutdown;

    uint256 public bitAmountMigrated;
    uint256 public mantleAmountMigrated;

    constructor(address _bit) {
        require(_bit != address(0), "Zero address: bit");
        bit = IERC20(_bit);
    }

    /* ========== MIGRATION ========== */

    // migrate bit to mantle
    function migrate(uint256 _amount) external {
        require(!shutdown, "Shut down");

        uint256 amount = (_amount * CONVERATION_NUMERATOR) / CONVERATION_DENOMINATOR;

        bit.safeTransferFrom(msg.sender, address(this), _amount);

        _send(_amount, amount);
    }

    // deposit mantle here
    function deposit(uint256 _amount) external {
        IERC20(mantle).safeTransferFrom(msg.sender, address(this), _amount);
    }

    // send token
    function _send(uint256 fromAmount, uint256 toAmount) internal {
        bitAmountMigrated = bitAmountMigrated + fromAmount;
        mantleAmountMigrated = mantleAmountMigrated + toAmount;
        uint256 mantleAmountBalance = IERC20(mantle).balanceOf(address(this));
        require(toAmount <= mantleAmountBalance, "Insufficient: not sufficient mantle");

        mantle.safeTransfer(msg.sender, toAmount);
    }

    /* ========== OWNABLE ========== */

    // halt migrations
    function halt() external onlyOwner {
        shutdown = !shutdown;
    }

    // set mantle address
    function setMantle(address _mantle) external onlyOwner {
        require(address(mantle) == address(0), "Already set");
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
