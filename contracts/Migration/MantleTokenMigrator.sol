// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../interfaces/IERC20.sol";

contract MantleTokenMigrator {

    /* ========== STATE VARIABLES ========== */

    address public immutable BIT_TOKEN_ADDRESS;
    address public immutable MNT_TOKEN_ADDRESS;

    uint256 public immutable TOKEN_SWAP_RATIO;
    uint256 public immutable TOKEN_SWAP_SCALING_FACTOR;
    
    address public treasury;
    address public owner;

    bool public halted;

    /* ========== EVENTS ========== */

    // TokenSwap Events
    event TokensMigrated(address indexed to, uint256 indexed amountOfBitSwapped, uint256 indexed amountOfMntRecieved);

    // Contract State Events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ContractHalted(address indexed halter);
    event ContractUnhalted(address indexed halter);
    event TreasuryChanged(address indexed previousTreasury, address indexed newTreasury);

    // Admin Events
    event TokensSwept(address indexed token, address indexed recipient, uint256 amount);
    event ContractFunded(address indexed funder, address indexed tokenAddress, uint256 amount);
    event ContractDefunded(address indexed funder, address indexed tokenAddress, uint256 amount);

    /* ========== ERRORS ========== */

    error MantleTokenMigrator_OnlyOwner(address caller);
    error MantleTokenMigrator_OnlyWhenNotHalted();
    error MantleTokenMigrator_ImproperlyInitialized();
    error MantleTokenMigrator_InsufficientContractBalance(address token, uint256 contractBalance, uint256 amountToTransfer);
    error MantleTokenMigrator_TransferFailed(address token, uint256 amount);
    error MantleTokenMigrator_SweepNotAllowed(address token);
    error MantleTokenMigrator_InvalidFundingToken(address token);
    error MantleTokenMigrator_InvalidMessageData(bytes data);
    error MantleTokenMigrator_EthNotAccepted();

    /* ========== MODIFIERS ========== */

    modifier onlyOwner {
        if (msg.sender != owner) revert MantleTokenMigrator_OnlyOwner(msg.sender);
        _;
    }

    modifier onlyWhenNotHalted {
        if (halted) revert MantleTokenMigrator_OnlyWhenNotHalted();
        _;
    }

    constructor(address _bitTokenAddress, address _mntTokenAddress, address _treasury, uint256 _tokenSwapRatio, uint256 _tokenSwapScalingFactor) {
        if (_bitTokenAddress == address(0) || _mntTokenAddress == address(0) || _treasury == address(0) || _tokenSwapRatio== 0 || _tokenSwapScalingFactor == 0) revert MantleTokenMigrator_ImproperlyInitialized();

        owner = msg.sender;
        halted = true;
        
        BIT_TOKEN_ADDRESS = _bitTokenAddress;
        MNT_TOKEN_ADDRESS = _mntTokenAddress;

        treasury = _treasury;

        TOKEN_SWAP_RATIO = _tokenSwapRatio;
        TOKEN_SWAP_SCALING_FACTOR = _tokenSwapScalingFactor;
    }


    /* ========== FALLBACKS ========== */
    fallback() external payable {
        // calls sending ether to the contract without calldata will use the recieve() hook
        if (msg.data.length != 0) revert MantleTokenMigrator_InvalidMessageData(msg.data);
    }

    receive() external payable {
        // we do not accept ETH in this contract, so revert
        // calls sending ether to this contract with valid calldata will revert because we have no payable functions
        // @note you can force ETH into this contract with a selfdestruct, but it has no impact on the contract state
        revert MantleTokenMigrator_EthNotAccepted();
    }

    /* ========== TOKEN SWAPPING ========== */

    function swapAllBIT() onlyWhenNotHalted external {
        uint256 amount = IERC20(BIT_TOKEN_ADDRESS).balanceOf(msg.sender);
        _swapTokens(amount);
    }

    function swapBIT(uint256 _amount) onlyWhenNotHalted external {
        _swapTokens(_amount);
    }

    function _swapTokens(uint256 _amount) internal {
        uint256 amountToSwap = _tokenSwapCalculation(_amount);

        // transfer user's BIT tokens to this contract
        bool success = IERC20(BIT_TOKEN_ADDRESS).transferFrom(msg.sender, address(this), _amount);
        if (success == false) revert MantleTokenMigrator_TransferFailed(BIT_TOKEN_ADDRESS, _amount);

        // transfer MNT tokens to user, if there are insufficient tokens, in the contract this will revert
        success = IERC20(MNT_TOKEN_ADDRESS).transfer(msg.sender, amountToSwap);
        if (success == false) revert MantleTokenMigrator_InsufficientContractBalance(MNT_TOKEN_ADDRESS, IERC20(MNT_TOKEN_ADDRESS).balanceOf(address(this)), amountToSwap);

        emit TokensMigrated(msg.sender, _amount, amountToSwap);
    }

    function _tokenSwapCalculation(uint256 _amount) internal returns (uint256) {
        return (_amount * TOKEN_SWAP_RATIO) / TOKEN_SWAP_SCALING_FACTOR;
    }

    function tokenMigrationAmountToRecieve(uint256 _amount) external returns (uint256) {
        return _tokenSwapCalculation(_amount);
    }

    /* ========== ADMIN UTILS ========== */

    // Ownership Functions
    function transferOwnership(address _newOwner) public onlyOwner {
        owner = _newOwner;

        emit OwnershipTransferred(msg.sender, _newOwner);
    }

    // Contract State Functions
    function haltContract() public onlyOwner {
        halted = true;

        emit ContractHalted(msg.sender);
    }

    function unhaltContract() public onlyOwner {
        halted = false;

        emit ContractUnhalted(msg.sender);
    }
    function setTreasury(address _treasury) public onlyOwner {
        address oldTreasury = treasury;
        treasury = _treasury;

        emit TreasuryChanged(oldTreasury, _treasury);
    }

    // Token Management Functions
    function defundContract(address _tokenAddress, uint256 _amount) public onlyOwner {
        if (_tokenAddress != BIT_TOKEN_ADDRESS && _tokenAddress != MNT_TOKEN_ADDRESS) revert MantleTokenMigrator_InvalidFundingToken(_tokenAddress);

        // we can only defund BIT or MNT into the predefined treasury address
        bool success = IERC20(_tokenAddress).transfer(treasury, _amount);
        if (success == false) revert MantleTokenMigrator_TransferFailed(_tokenAddress, _amount);

        emit ContractDefunded(treasury, _tokenAddress, _amount);
    }

    function sweepTokens (address _tokenAddress, address _recipient, uint256 _amount) public onlyOwner {
        // we can only sweep tokens that are not BIT or MNT to an arbitrary addres
        if ((_tokenAddress == address(BIT_TOKEN_ADDRESS)) || (_tokenAddress == address(MNT_TOKEN_ADDRESS))) revert MantleTokenMigrator_SweepNotAllowed(_tokenAddress);
        bool success = IERC20(_tokenAddress).transfer(_recipient, _amount);
        if (success == false) revert MantleTokenMigrator_TransferFailed(_tokenAddress, _amount);

        emit TokensSwept(_tokenAddress, _recipient, _amount);
    }

}
