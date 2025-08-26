// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../contracts/L1/L1MantleToken.sol";

import "@openzeppelin/contracts-v4/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts-v4/proxy/transparent/TransparentUpgradeableProxy.sol";

import "forge-std/Test.sol";
import "./mocks/EmptyContract.sol";

contract L1MantleTokenTest is Test {
    ProxyAdmin public proxyAdmin;
    L1MantleToken public l1MantleToken;

    uint256 public _initialSupply = 10e10;
    address public initialOwner = address(this);

    address public mintTo = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    bytes public err;

    uint256 constant MAX_UINT256 = (2 ** 256) - 1;

    function setUp() public {
        proxyAdmin = new ProxyAdmin();
        EmptyContract emptyContract = new EmptyContract();

        l1MantleToken =
            L1MantleToken(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));

        L1MantleToken l1MantleTokenImplementation = new L1MantleToken();

        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(l1MantleToken))),
            address(l1MantleTokenImplementation),
            abi.encodeWithSelector(L1MantleToken.initialize.selector, _initialSupply, initialOwner)
        );
    }

    function test_Info() public {
        assertEq(l1MantleToken.name(), "Mantle");
        assertEq(l1MantleToken.symbol(), "MNT");
        assertEq(l1MantleToken.decimals(), 18);
        assertEq(l1MantleToken.MIN_MINT_INTERVAL(), 365 * 24 * 60 * 60);
        assertEq(l1MantleToken.MINT_CAP_DENOMINATOR(), 10000);
        assertEq(l1MantleToken.mintCapNumerator(), 0);
        assertEq(l1MantleToken.nextMint(), 365 * 24 * 60 * 60 + 1);
    }

    function test_Initialize() public {
        assertEq(l1MantleToken.totalSupply(), 10e10);
        assertEq(l1MantleToken.owner(), initialOwner);
    }

    function test_setMintCapNumeratorFuzz(uint256 _mintCapNumerator) public {
        vm.assume(_mintCapNumerator <= 200);

        l1MantleToken.setMintCapNumerator(_mintCapNumerator);
        uint256 postSet = l1MantleToken.mintCapNumerator();
        assertEq(postSet, _mintCapNumerator);
    }

    function test_setMintCapNumeratorTooLargeFuzz(uint256 _mintCapNumerator) public {
        vm.assume(_mintCapNumerator > 200);

        uint256 maximumMintAmount =
            (l1MantleToken.totalSupply() * l1MantleToken.mintCapNumerator()) / l1MantleToken.MINT_CAP_DENOMINATOR();

        err = abi.encodeWithSignature(
            "MantleToken_MintCapNumeratorTooLarge(uint256,uint256)",
            _mintCapNumerator,
            l1MantleToken.MINT_CAP_MAX_NUMERATOR()
        );
        vm.expectRevert(err);
        l1MantleToken.setMintCapNumerator(_mintCapNumerator);
    }

    function test_MintOnlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0));
        l1MantleToken.mint(mintTo, 1);
    }

    function test_MintFuzz(uint256 _amount, uint256 _blockTimestamp) public {
        l1MantleToken.setMintCapNumerator(200);

        uint256 maximumMintAmount =
            (l1MantleToken.totalSupply() * l1MantleToken.mintCapNumerator()) / l1MantleToken.MINT_CAP_DENOMINATOR();

        vm.assume(_amount <= maximumMintAmount);
        vm.assume(
            _blockTimestamp >= l1MantleToken.nextMint()
                && _blockTimestamp < MAX_UINT256 - l1MantleToken.MIN_MINT_INTERVAL()
        );

        vm.warp(_blockTimestamp);

        uint256 preBalance = l1MantleToken.balanceOf(mintTo);
        l1MantleToken.mint(mintTo, _amount);
        uint256 postBalance = l1MantleToken.balanceOf(mintTo);
        assertEq(preBalance + _amount, postBalance);
    }

    function test_Mint() public {
        l1MantleToken.setMintCapNumerator(200);
        uint256 postSet = l1MantleToken.mintCapNumerator();
        assertEq(postSet, 200);

        vm.warp(365 * 24 * 60 * 60 + 1);

        uint256 maxAmount = 2000000000;
        uint256 preBalance = l1MantleToken.balanceOf(mintTo);
        l1MantleToken.mint(mintTo, maxAmount);
        uint256 postBalance = l1MantleToken.balanceOf(mintTo);
        assertEq(preBalance + maxAmount, postBalance);
    }

    function test_MintTooMuchFuzz(uint256 _amount, uint256 _blockTimestamp) public {
        l1MantleToken.setMintCapNumerator(200);

        uint256 maximumMintAmount =
            (l1MantleToken.totalSupply() * l1MantleToken.mintCapNumerator()) / l1MantleToken.MINT_CAP_DENOMINATOR();

        vm.assume(_amount > maximumMintAmount);
        vm.assume(
            _blockTimestamp >= l1MantleToken.nextMint()
                && _blockTimestamp < MAX_UINT256 - l1MantleToken.MIN_MINT_INTERVAL()
        );

        vm.warp(_blockTimestamp);

        err = abi.encodeWithSignature("MantleToken_MintAmountTooLarge(uint256,uint256)", _amount, maximumMintAmount);
        vm.expectRevert(err);
        l1MantleToken.mint(mintTo, _amount);
    }

    function testMintTooMuch1() public {
        uint256 maximumMintAmount =
            (l1MantleToken.totalSupply() * l1MantleToken.mintCapNumerator()) / l1MantleToken.MINT_CAP_DENOMINATOR();

        err = abi.encodeWithSignature("MantleToken_MintAmountTooLarge(uint256,uint256)", 1, maximumMintAmount);
        vm.expectRevert(err);
        l1MantleToken.mint(mintTo, 1);
    }

    function testMintTooMuch2() public {
        l1MantleToken.setMintCapNumerator(200);
        uint256 postSet = l1MantleToken.mintCapNumerator();
        assertEq(postSet, 200);

        vm.warp(365 * 24 * 60 * 60 + 1);

        uint256 maximumMintAmount =
            (l1MantleToken.totalSupply() * l1MantleToken.mintCapNumerator()) / l1MantleToken.MINT_CAP_DENOMINATOR();

        err = abi.encodeWithSignature(
            "MantleToken_MintAmountTooLarge(uint256,uint256)", maximumMintAmount + 1, maximumMintAmount
        );
        vm.expectRevert(err);
        l1MantleToken.mint(mintTo, maximumMintAmount + 1);
    }

    function test_MintTooEarlyFuzz(uint256 _amount, uint256 _blockTimestamp, bool _setMintCapNumerator) public {
        if (_setMintCapNumerator) {
            l1MantleToken.setMintCapNumerator(200);
        }

        vm.assume(
            _amount
                <= (l1MantleToken.totalSupply() * l1MantleToken.mintCapNumerator()) / l1MantleToken.MINT_CAP_DENOMINATOR()
        );
        vm.assume(_blockTimestamp < l1MantleToken.nextMint());

        vm.warp(_blockTimestamp);

        err = abi.encodeWithSignature(
            "MantleToken_NextMintTimestampNotElapsed(uint256,uint256)", block.timestamp, l1MantleToken.nextMint()
        );
        vm.expectRevert(err);
        l1MantleToken.mint(mintTo, _amount);
    }

    function test_MintTooEarly1() public {
        err = abi.encodeWithSignature(
            "MantleToken_NextMintTimestampNotElapsed(uint256,uint256)", block.timestamp, l1MantleToken.nextMint()
        );
        vm.expectRevert(err);
        l1MantleToken.mint(mintTo, 0);
    }

    function test_MintTooEarly2() public {
        l1MantleToken.setMintCapNumerator(200);
        uint256 postSet = l1MantleToken.mintCapNumerator();
        assertEq(postSet, 200);

        err = abi.encodeWithSignature(
            "MantleToken_NextMintTimestampNotElapsed(uint256,uint256)", block.timestamp, l1MantleToken.nextMint()
        );
        vm.expectRevert(err);
        l1MantleToken.mint(mintTo, 1);
    }

    function test_MintTooEarly3() public {
        l1MantleToken.setMintCapNumerator(200);
        uint256 postSet = l1MantleToken.mintCapNumerator();
        assertEq(postSet, 200);

        vm.warp(365 * 24 * 60 * 60);

        err = abi.encodeWithSignature(
            "MantleToken_NextMintTimestampNotElapsed(uint256,uint256)", block.timestamp, l1MantleToken.nextMint()
        );
        vm.expectRevert(err);
        l1MantleToken.mint(mintTo, 1);
    }

    function testMintTooEarly4() public {
        l1MantleToken.setMintCapNumerator(200);
        uint256 postSet = l1MantleToken.mintCapNumerator();
        assertEq(postSet, 200);

        vm.warp(365 * 24 * 60 * 60 + 1);

        uint256 maxAmount = 2000000000;
        l1MantleToken.mint(mintTo, maxAmount - 1);

        err = abi.encodeWithSignature(
            "MantleToken_NextMintTimestampNotElapsed(uint256,uint256)", block.timestamp, l1MantleToken.nextMint()
        );
        vm.expectRevert(err);
        l1MantleToken.mint(mintTo, 1);
    }
}
