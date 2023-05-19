// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../contracts/L1/L1MantleToken.sol";
import "../../contracts/Mock/ERC20Mock.sol";
import "../../contracts/Migration/MantleTokenMigrator.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "forge-std/Test.sol";
import "./mocks/EmptyContract.sol";

contract MantleTokenMigratorTest is Test {
    ProxyAdmin public proxyAdmin;
    L1MantleToken public l1MantleToken;
    ERC20Mock public bit;
    ERC20Mock public otherERC20Mock;
    MantleTokenMigrator public mtm;

    uint256 _initialSupply = 10e10;
    address initialOwner = address(this);
    address mintTo = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    function setUp() public {
        proxyAdmin = new ProxyAdmin();
        EmptyContract emptyContract = new EmptyContract();

        l1MantleToken = L1MantleToken(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), ""))
        );

        L1MantleToken l1MantleTokenImplementation = new L1MantleToken();

        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(l1MantleToken))),
            address(l1MantleTokenImplementation),
            abi.encodeWithSelector(L1MantleToken.initialize.selector, _initialSupply, initialOwner)
        );

        bit = new ERC20Mock();
        otherERC20Mock = new ERC20Mock();

        mtm = new MantleTokenMigrator(address(bit));
    }

    function testInfo() public {
        assertEq(mtm.CONVERSION_DENOMINATOR(), 100);
        assertEq(mtm.CONVERSION_NUMERATOR(), 314);
        assertEq(mtm.bitAmountMigrated(), 0);
        assertEq(mtm.mantleAmountMigrated(), 0);
        assertEq(mtm.enabled(), false);
    }

    function testPauseAndUnpause() public {
        mtm.pause();
        assertEq(mtm.enabled(), false);

        mtm.unpause();
        assertEq(mtm.enabled(), true);
        mtm.unpause();
        assertEq(mtm.enabled(), true);

        mtm.pause();
        assertEq(mtm.enabled(), false);
        mtm.pause();
        assertEq(mtm.enabled(), false);
    }

    function testPauseOnlyowner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0));
        mtm.pause();
    }

    function testUnPauseOnlyowner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0));
        mtm.unpause();
    }

    function testSetMantleUnuseZeroAddress() public {
        vm.expectRevert("ERC-20 MNT contract cannot be zerobit");
        mtm.setMantle(address(0));
    }

    function testSetMantle() public {
        mtm.setMantle(address(l1MantleToken));
    }

    function testSetMantletwice() public {
        mtm.setMantle(address(l1MantleToken));
        vm.expectRevert("Already set, only can be set once");
        mtm.setMantle(address(0));
    }

    function testWithdrawTokenUnuseZeroAddress() public {
        vm.expectRevert("Token address cannot be 0x0");
        mtm.withdrawToken(address(0), 1, address(1));
    }

    function testWithdrawTokenUnuseBIT() public {
        mtm.withdrawToken(address(bit), 1, address(1));
    }

    // // Invalid implicit conversion from int_const -1 to uint256 requested
    // function testWithdrawMorethanZero() public {

    //     vm.expectRevert("Withdraw value must be greater than 0");
    //     mtm.withdrawToken(address(l1MantleToken), -1, address(1));
    // }

    function testWithdrawToken() public {
        mtm.withdrawToken(address(l1MantleToken), 1, address(1));
    }

    function testDeposit() public {
        l1MantleToken.transfer(address(mtm), 1);

        mtm.setMantle(address(l1MantleToken));

        assertEq(l1MantleToken.balanceOf(address(mtm)), 1);
    }

    function testDepositWithOtherERC20() public {
        otherERC20Mock.mint(address(this), 100);
        otherERC20Mock.transfer(address(mtm), 1);

        mtm.setMantle(address(otherERC20Mock));

        assertEq(otherERC20Mock.balanceOf(address(mtm)), 1);
    }

    function testDepositAndWithdraw() public {
        l1MantleToken.transfer(address(mtm), 1);

        mtm.setMantle(address(l1MantleToken));

        assertEq(l1MantleToken.balanceOf(address(mtm)), 1);

        mtm.withdrawToken(address(l1MantleToken), 1, address(1));
        assertEq(l1MantleToken.balanceOf(address(mtm)), 0);
        assertEq(l1MantleToken.balanceOf(address(1)), 1);
    }

    function testDepositAndWithdrawAfterTransfer() public {
        l1MantleToken.transfer(address(mtm), 1);

        // mtm.setMantle(address(l1MantleToken));

        assertEq(l1MantleToken.balanceOf(address(mtm)), 1);

        mtm.withdrawToken(address(l1MantleToken), 1, address(1));
        assertEq(l1MantleToken.balanceOf(address(mtm)), 0);
        assertEq(l1MantleToken.balanceOf(address(1)), 1);
    }

    function testMigrate() public {
        uint256 bitAmount = 1000;
        uint256 l1MantleAmount = 10000;

        // mint bitAmount BIT to address(2)
        bit.mint(address(2), bitAmount);

        // transfer l1MantleAmount l1MantleToken to MantleTokenMigrator contract
        mtm.setMantle(address(l1MantleToken));
        l1MantleToken.transfer(address(mtm), l1MantleAmount);
        assertEq(l1MantleToken.balanceOf(address(mtm)), l1MantleAmount);

        // unpause MantleTokenMigrator
        mtm.unpause();

        vm.prank(address(2));
        // address(2) approve bitAmount BIT
        bit.approve(address(mtm), bitAmount);
        assertEq(bit.allowance(address(2), address(mtm)), bitAmount);

        // swap token
        vm.prank(address(2));
        mtm.migrate(bitAmount);

        assertEq(mtm.bitAmountMigrated(), bitAmount);
        assertEq(mtm.mantleAmountMigrated(), (bitAmount * mtm.CONVERSION_NUMERATOR()) / mtm.CONVERSION_DENOMINATOR());
        assertEq(bit.balanceOf(address(mtm)), bitAmount);
        assertEq(l1MantleToken.balanceOf(address(mtm)), l1MantleAmount - mtm.mantleAmountMigrated());
    }

    function testMigrateInsufficient() public {
        uint256 bitAmount = 10000;
        uint256 l1MantleAmount = 10000;

        // mint bitAmount BIT to address(2)
        bit.mint(address(2), bitAmount);

        // transfer l1MantleAmount l1MantleToken to MantleTokenMigrator contract
        mtm.setMantle(address(l1MantleToken));
        l1MantleToken.transfer(address(mtm), l1MantleAmount);
        assertEq(l1MantleToken.balanceOf(address(mtm)), l1MantleAmount);

        // unpause MantleTokenMigrator
        mtm.unpause();

        vm.prank(address(2));
        // address(2) approve bitAmount BIT
        bit.approve(address(mtm), bitAmount);
        assertEq(bit.allowance(address(2), address(mtm)), bitAmount);

        // swap token
        vm.expectRevert("Insufficient mantle tokens");
        vm.prank(address(2));
        mtm.migrate(bitAmount);
    }
}
