// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../contracts/L1/L1MantleToken.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "forge-std/Test.sol";
import "./mocks/EmptyContract.sol";

contract L1MantleTokenTest is Test {
    ProxyAdmin public proxyAdmin;
    L1MantleToken public l1MantleToken;
    uint256 _initialSupply = 10e10;
    address initialOwner = address(this);
    address mintTo = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

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

    function testInfo() public {
        assertEq(l1MantleToken.name(), "Mantle");
        assertEq(l1MantleToken.symbol(), "MNT");
        assertEq(l1MantleToken.decimals(), 18);
        assertEq(l1MantleToken.MIN_MINT_INTERVAL(), 365 * 24 * 60 * 60);
        assertEq(l1MantleToken.MINT_CAP_DENOMINATOR(), 10000);
        assertEq(l1MantleToken.mintCapNumerator(), 0);
        assertEq(l1MantleToken.nextMint(), 365 * 24 * 60 * 60 + 1);
    }

    function testInitialize() public {
        assertEq(l1MantleToken.totalSupply(), 10e10);
        assertEq(l1MantleToken.owner(), initialOwner);
    }

    function testSetMintCapNumerator(uint256 _mintCapNumerator) public {
        l1MantleToken.setMintCapNumerator(_mintCapNumerator);
        uint256 postSet = l1MantleToken.mintCapNumerator();
        assertEq(postSet, _mintCapNumerator);
    }

    function testMintOnlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0));
        l1MantleToken.mint(mintTo, 1);
    }

    function testMintTooMuch1() public {
        vm.expectRevert("MANTLE: MINT_TOO_MUCH");
        l1MantleToken.mint(mintTo, 1);
    }

    function testMintTooEarly1() public {
        vm.expectRevert("MANTLE: MINT_TOO_EARLY");
        l1MantleToken.mint(mintTo, 0);
    }

    function testMintTooEarly2() public {
        l1MantleToken.setMintCapNumerator(200);
        uint256 postSet = l1MantleToken.mintCapNumerator();
        assertEq(postSet, 200);

        vm.expectRevert("MANTLE: MINT_TOO_EARLY");
        l1MantleToken.mint(mintTo, 1);
    }

    function testMintTooEarly3() public {
        l1MantleToken.setMintCapNumerator(200);
        uint256 postSet = l1MantleToken.mintCapNumerator();
        assertEq(postSet, 200);

        vm.warp(365 * 24 * 60 * 60);

        vm.expectRevert("MANTLE: MINT_TOO_EARLY");
        l1MantleToken.mint(mintTo, 1);
    }

    function testMint() public {
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

    function testMintTooMuch2() public {
        l1MantleToken.setMintCapNumerator(200);
        uint256 postSet = l1MantleToken.mintCapNumerator();
        assertEq(postSet, 200);

        vm.warp(365 * 24 * 60 * 60 + 1);

        uint256 maxAmount = 2000000000;
        vm.expectRevert("MANTLE: MINT_TOO_MUCH");
        l1MantleToken.mint(mintTo, maxAmount + 1);
    }

    function testMintTooEarly4() public {
        l1MantleToken.setMintCapNumerator(200);
        uint256 postSet = l1MantleToken.mintCapNumerator();
        assertEq(postSet, 200);

        vm.warp(365 * 24 * 60 * 60 + 1);

        uint256 maxAmount = 2000000000;
        l1MantleToken.mint(mintTo, maxAmount - 1);

        vm.expectRevert("MANTLE: MINT_TOO_EARLY");
        l1MantleToken.mint(mintTo, 1);
    }
}

// allowance
// approve
// balanceOf
// decreaseAllowance
// increaseAllowance
// renounceOwnership
// transfer
// transferFrom
// transferOwnership

// burn
// burnFrom
// checkpoints
// DOMAIN_SEPARATOR
// delegate
// delegateBySig
// delegates
// getPastTotalSupply
// getPastVotes
// getVotes
// nonces
// numCheckpoints
// permit
