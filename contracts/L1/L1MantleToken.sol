// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


/// @title L1MantleToken
/// @author 0xMantle
/// @notice ERC20 token with minting and burning functionality
contract L1MantleToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    OwnableUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable
{
    /* ========== STATE VARIABLES ========== */

    string private constant NAME = "Mantle";
    string private constant SYMBOL = "MNT";

    /// @dev The minimum amount of time that must elapse before a mint is allowed
    uint256 public constant MIN_MINT_INTERVAL = 365 days;

    /// @dev The denominator of the maximum fractional amount that can be minted
    uint256 public constant MINT_CAP_DENOMINATOR = 10_000;

    /// @dev The numerator of the maximum fractional amount that can be minted
    uint256 public constant MINT_CAP_MAX_NUMERATOR = 200;

    /// @dev The current numerator of the fractional amount that can be minted
    uint256 public mintCapNumerator;

    /// @dev The blockTimeStamp at which mint will be able to be called again
    uint256 public nextMint;

    /* ========== EVENTS ========== */

    /// @dev Emitted when the mintCapNumerator is set
    /// @param from The address which changed the mintCapNumerator
    /// @param previousMintCapNumerator The previous mintCapNumerator
    /// @param newMintCapNumerator The new mintCapNumerator
    event MintCapNumeratorChanged(address indexed from, uint256 indexed previousMintCapNumerator, uint256 indexed newMintCapNumerator);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* ========== INITIALIZER ========== */

    /// @notice Initializes the L1MantleToken contract, setting the inital total supply as {initialSupply} and the owner as {_owner}
    /// @dev the mintCapNumerator should not be set as it is initialized as 0
    /// @dev Requirements:
    ///     - all parameters must be non-zero
    /// @param _initialSupply The initial total supply of the token
    /// @param _owner The owner of the token

    function initialize(uint256 _initialSupply, address _owner) public initializer {
        require(_initialSupply != 0, "MANTLE: ZERO_INITIAL_SUPPLY");
        require(_owner != address(0), "MANTLE: ZERO_OWNER");

        __ERC20_init(NAME, SYMBOL);
        __ERC20Burnable_init();
        __Ownable_init();
        __ERC20Permit_init(NAME);
        __ERC20Votes_init();

        _mint(_owner, _initialSupply);
        nextMint = block.timestamp + MIN_MINT_INTERVAL;

        _transferOwnership(_owner);
    }



    /// @notice Allows the owner to mint new tokens and increase this token's total supply
    /// @dev Requirements:
    ///     - Only allows minting below an inflation cap at a specified time interval
    ///         - The max mint amount is computed as follows:  
    ///             - maxMintAmount = (mintCapNumerator * totalSupply()) / MINT_CAP_DENOMINATOR
    ///              - The specified time interval at which mints can occur is initially set to 1 year
    ///     - the parameter {amount} must be less than or equal to {maxMintAmount} as computed above
    ///     - the {blockTimestamp} of the block in which this function is called must be greater than or equal to {nextMint}
    /// @param recipient The address to mint tokens to
    /// @param amount The amount of tokens to mint
    function mint(address recipient, uint256 amount) public onlyOwner {
        require(amount <= (totalSupply() * mintCapNumerator) / MINT_CAP_DENOMINATOR, "MANTLE: MINT_TOO_MUCH");
        require(block.timestamp >= nextMint, "MANTLE: MINT_TOO_EARLY");

        nextMint = block.timestamp + MIN_MINT_INTERVAL;
        _mint(recipient, amount);
    }

    /// @notice Allows the owner to set the mintCapNumerator
    /// @dev emits a {MintCapNumeratorSet} event
    /// @dev Requirements:
    ///     - The caller must be the contract owner
    ///     - parameter {_mintCapNumerator} must be less than or equal to {MINT_CAP_MAX_NUMERATOR}
    function setMintCapNumerator(uint256 _mintCapNumerator) public onlyOwner {
        require(_mintCapNumerator <= MINT_CAP_MAX_NUMERATOR, "MANTLE: MAX_INFLATION IS 2%");
        uint256 previousMintCapNumerator = mintCapNumerator;
        mintCapNumerator = _mintCapNumerator;

        emit MintCapNumeratorChanged(msg.sender, previousMintCapNumerator, mintCapNumerator);
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    /// @inheritdoc ERC20Upgradeable
    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    /// @inheritdoc ERC20Upgradeable
    function _mint(address to, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._mint(to, amount);
    }

    /// @inheritdoc ERC20Upgradeable
    function _burn(address account, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._burn(account, amount);
    }
}
