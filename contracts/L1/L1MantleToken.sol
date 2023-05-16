// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./TransferAndCallToken.sol";

contract L1MantleToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    OwnableUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    TransferAndCallToken
{
    string private constant NAME = "Mantle";
    string private constant SYMBOL = "MNT";
    /// @notice The minimum amount of time that must elapse before a mint is allowed
    uint256 public constant MIN_MINT_INTERVAL = 365 days;
    /// @notice The amount that can be can be minted - denominator
    uint256 public constant MINT_CAP_DENOMINATOR = 10_000;
    /// @notice The amount that can be can be minted - numerator
    uint256 public mintCapNumerator = 0;
    /// @notice The time at which the next mint is allowed - timestamp
    uint256 public nextMint;

    /// events
    event SetMintCapNumerator(address from, uint256 mintCapNumerator);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

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

    /// @notice Allows the owner to mint new tokens
    /// @dev Only allows minting below an inflation cap.
    /// Set to once per year, and a maximum of inflation.
    /// Inflation = mintCapNumerator / MINT_CAP_DENOMINATOR, if mintCapNumerator is 200, the inflation will be 2%.
    function mint(address recipient, uint256 amount) public onlyOwner {
        require(amount <= (totalSupply() * mintCapNumerator) / MINT_CAP_DENOMINATOR, "MANTLE: MINT_TOO_MUCH");
        require(block.timestamp >= nextMint, "MANTLE: MINT_TOO_EARLY");

        nextMint = block.timestamp + MIN_MINT_INTERVAL;
        _mint(recipient, amount);
    }

    function setMintCapNumerator(uint256 _mintCapNumerator) public onlyOwner {
        mintCapNumerator = _mintCapNumerator;

        emit SetMintCapNumerator(msg.sender, mintCapNumerator);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._burn(account, amount);
    }
}
