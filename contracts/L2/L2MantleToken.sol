// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
// import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract L2MantleToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    OwnableUpgradeable,
    ERC20VotesUpgradeable
{
    string private constant NAME = "Mantle";
    string private constant SYMBOL = "mantle";

    address public l2MantleBridge;
    address public governance;
    bool public governanceEnabled;

    /// events
    event EnableGovernance(address from, bool governanceEnabled);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _l2MantleBridge, address _governance, address _owner) public initializer {
        require(_l2MantleBridge != address(0), "L2MantleToken: zero l2 mantle bridge");

        __ERC20_init(NAME, SYMBOL);
        __ERC20Burnable_init();
        __Ownable_init();
        __ERC20Votes_init();

        l2MantleBridge = _l2MantleBridge;
        governance = _governance;

        _transferOwnership(_owner);
    }

    modifier onlyL2MantleBridge() {
        require(msg.sender == l2MantleBridge, "L2MantleToken: only l2 mantle bridge");
        _;
    }

    modifier onlyGovernance() {
        require(msg.sender == l2MantleBridge, "L2MantleToken: only governance");
        _;
    }

    modifier onlyGovernanceEnabled() {
        require(governanceEnabled, "L2MantleToken: only governance enabled");
        _;
    }

    /// @notice Allow the L2 Mantle Bridge to mint tokens
    function bridgeMint(address account, uint256 amount) public onlyL2MantleBridge {
        _mint(account, amount);
    }

    /// @notice Allow the L2 Mantle Bridge to burn tokens
    function bridgeBurn(address account, uint256 amount) public onlyL2MantleBridge {
        _burn(account, amount);
    }

    /// @notice Enable governance on L2
    function enableGovernance(bool _governanceEnabled) public onlyGovernance {
        governanceEnabled = _governanceEnabled;

        emit EnableGovernance(msg.sender, _governanceEnabled);
    }

    /// @notice delegate
    function delegate(address delegatee) public virtual override(ERC20VotesUpgradeable) onlyGovernanceEnabled {
        super.delegate(delegatee);
    }

    /// @notice delegateBySig
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override(ERC20VotesUpgradeable) onlyGovernanceEnabled {
        super.delegateBySig(delegatee, nonce, expiry, v, r, s);
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

    /// L2 Mantle Token acts as a native token, and the following methods will be banned.
    /// transfer, approve, transferFrom, increaseAllowance, decreaseAllowance, burn, burnFrom, permit
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        revert("BVM_Mantle: transfer is disabled pending further community discussion.");
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        revert("BVM_Mantle: approve is disabled pending further community discussion.");
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        revert("BVM_Mantle: transferFrom is disabled pending further community discussion.");
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual override returns (bool) {
        revert("BVM_Mantle: increaseAllowance is disabled pending further community discussion.");
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual override returns (bool) {
        revert("BVM_Mantle: decreaseAllowance is disabled pending further community discussion.");
    }

    function burn(uint256 amount) public virtual override {
        revert("BVM_Mantle: burn is disabled pending further community discussion.");
    }

    function burnFrom(address account, uint256 amount) public virtual override {
        revert("BVM_Mantle: burnFrom is disabled pending further community discussion.");
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        revert("BVM_Mantle: permit is disabled pending further community discussion.");
    }
}
