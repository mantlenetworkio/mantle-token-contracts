// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MantleTokenMigrator is Ownable {
    using SafeMath for uint256;

    address public governor;

    /// @notice The amount that can be can be minted - denominator
    uint256 public constant CONVERATION_DENOMINATOR = 100;
    /// @notice The amount that can be can be minted - numerator
    uint256 public constant CONVERATION_NUMERATOR = 314;

    /* ========== MIGRATION ========== */
    /* ========== STATE VARIABLES ========== */

    IERC20 public immutable oldMantle;
    IERC20 public newMantle;

    bool public shutdown;

    uint256 public oldMantleAmountMigrated;
    uint256 public newMantleAmountDeposited;
    uint256 public newMantleAmountMigrated;
    uint256 public newMantleAmountRemained;

    modifier onlyGovernor() {
        require(msg.sender == governor, "Caller is not a governor");
        _;
    }

    constructor(address _oldMantle, address _governor) {
        require(_oldMantle != address(0), "Zero address: old Mantle");
        oldMantle = IERC20(_oldMantle);

        governor = _governor;
    }

    /* ========== MIGRATION ========== */

    // migrate oldMantle to newMantle
    function migrate(uint256 _amount) external {
        require(!shutdown, "Shut down");

        uint256 amount = _amount.mul(CONVERATION_NUMERATOR).div(CONVERATION_DENOMINATOR);

        oldMantle.transferFrom(msg.sender, address(this), _amount);

        _send(_amount, amount);
    }

    // deposit newToken here
    function deposit(uint256 _amount) external {
        IERC20(newMantle).transferFrom(msg.sender, address(this), _amount);

        newMantleAmountDeposited = newMantleAmountDeposited + _amount;
        newMantleAmountRemained = newMantleAmountRemained + _amount;
    }

    // send token
    function _send(uint256 fromAmount, uint256 toAmount) internal {
        oldMantleAmountMigrated = oldMantleAmountMigrated + fromAmount;
        newMantleAmountMigrated = newMantleAmountMigrated + toAmount;
        newMantleAmountRemained = newMantleAmountRemained - toAmount;
        require(newMantleAmountRemained >= 0, "Insufficient: not sufficient new-mantle");

        newMantle.transfer(msg.sender, toAmount);
    }

    /* ========== OWNABLE ========== */

    // halt migrations
    function halt() external onlyGovernor {
        shutdown = !shutdown;
    }

    // set Governor
    function setGovernor(address _governor) external onlyOwner {
        require(_governor != address(0), "Zero address: new mantle");

        governor = _governor;
    }

    // set newMantle address
    function setNewMantle(address _newMantle) external onlyGovernor {
        require(address(newMantle) == address(0), "Already set");
        require(_newMantle != address(0), "Zero address: new mantle");

        newMantle = IERC20(_newMantle);
    }

    // function to allow owner to withdraw funds(tokens except old mantle) sent directly to contract
    function withdrawToken(address tokenAddress, uint256 amount, address recipient) external onlyGovernor {
        require(tokenAddress != address(0), "Token address cannot be 0x0");
        require(tokenAddress != address(oldMantle), "Cannot withdraw: old-mantle");
        require(amount > 0, "Withdraw value must be greater than 0");
        if (recipient == address(0)) {
            recipient = msg.sender; // if no address is specified the value will will be withdrawn to Owner
        }

        IERC20 tokenContract = IERC20(tokenAddress);
        uint256 contractBalance = tokenContract.balanceOf(address(this));
        if (amount > contractBalance) {
            amount = contractBalance; // set the withdrawal amount equal to balance within the account.
        }

        // update new mantle token balance
        if (tokenAddress == address(newMantle)) {
            newMantleAmountDeposited = newMantleAmountDeposited - amount;
            newMantleAmountRemained = newMantleAmountRemained - amount;
        }

        // transfer the token from address of this contract
        tokenContract.transfer(recipient, amount);
    }
}
