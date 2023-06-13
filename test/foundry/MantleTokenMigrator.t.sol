// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../contracts/Migration/MantleTokenMigrator.sol";
import "../../contracts/Mock/MockERC20.sol";
import "./utils/UserFactory.sol";

contract MantleTokenMigratorTest is Test {
    address public deployer;
    address public treasury;

    address public userOne;
    address public userTwo;
    address public userThree;

    uint256 tokenConversionNumerator;
    uint256 tokenConversionDenominator;

    UserFactory public userFactory;
    MantleTokenMigrator public mantleTokenMigrator;
    MockERC20 public tokenOne;
    MockERC20 public tokenTwo;
    MockERC20 public tokenToSweep;

    bytes public err;

    function setUp() public {
        userFactory = new UserFactory();
        address[] memory users = userFactory.create(5);
        deployer = users[0];
        treasury = users[1];
        userOne = users[2];
        userTwo = users[3];
        userThree = users[4];

        tokenConversionNumerator = 42069;
        tokenConversionDenominator = 10000;

        tokenOne = new MockERC20("Token One", "TKN1", 18);
        tokenTwo = new MockERC20("Token Two", "TKN2", 18);
        tokenToSweep = new MockERC20("Token To Sweep", "TKN3", 18);

        tokenOne.mint(userOne, 10000 ether);
        tokenOne.mint(userTwo, 10000 ether);

        tokenToSweep.mint(userThree, 10000 ether);

        tokenTwo.mint(treasury, 42069 * 2 ether);

        vm.startPrank(deployer);
        mantleTokenMigrator =
        new MantleTokenMigrator(address(tokenOne), address(tokenTwo), treasury, tokenConversionNumerator, tokenConversionDenominator);
        mantleTokenMigrator.unhaltContract();
        vm.stopPrank();
    }

    function test_mantleTokenMigratorCannotBeInitializedWithZeroValues() public {
        // iterate through each possible case of zero values

        vm.startPrank(deployer);

        err = abi.encodeWithSignature("MantleTokenMigrator_ImproperlyInitialized()");

        vm.expectRevert(err);
        mantleTokenMigrator =
        new MantleTokenMigrator(address(0), address(tokenTwo), treasury, tokenConversionNumerator, tokenConversionDenominator);

        vm.expectRevert(err);
        mantleTokenMigrator =
        new MantleTokenMigrator(address(tokenOne), address(0), treasury, tokenConversionNumerator, tokenConversionDenominator);

        vm.expectRevert(err);
        mantleTokenMigrator =
        new MantleTokenMigrator(address(tokenOne), address(tokenTwo), address(0), tokenConversionNumerator, tokenConversionDenominator);

        vm.expectRevert(err);
        mantleTokenMigrator =
            new MantleTokenMigrator(address(tokenOne), address(tokenTwo), treasury, 0, tokenConversionDenominator);

        vm.expectRevert(err);
        mantleTokenMigrator =
            new MantleTokenMigrator(address(tokenOne), address(tokenTwo), treasury, tokenConversionNumerator, 0);

        vm.stopPrank();
    }

    function test_TreasuryCannotBeSetToZeroValues() public {
        vm.startPrank(deployer);

        err = abi.encodeWithSignature("MantleTokenMigrator_InvalidTreasury(address)", address(0));

        vm.expectRevert(err);
        mantleTokenMigrator.setTreasury(address(0));

        vm.stopPrank();
    }

    function test_mantleTokenMigratorCorrectlyInitialized() public {
        // make sure the contract is initialized with the correct values
        assertEq(mantleTokenMigrator.owner(), deployer);

        assertEq(mantleTokenMigrator.BIT_TOKEN_ADDRESS(), address(tokenOne));
        assertEq(mantleTokenMigrator.MNT_TOKEN_ADDRESS(), address(tokenTwo));

        assertEq(mantleTokenMigrator.treasury(), treasury);

        assertEq(mantleTokenMigrator.TOKEN_CONVERSION_NUMERATOR(), tokenConversionNumerator);
        assertEq(mantleTokenMigrator.TOKEN_CONVERSION_DENOMINATOR(), tokenConversionDenominator);

        // make sure modifiers are correctly reached
        err = abi.encodeWithSignature("MantleTokenMigrator_OnlyOwner(address)", address(this));
        vm.expectRevert(err);
        mantleTokenMigrator.haltContract();

        vm.startPrank(deployer);
        mantleTokenMigrator.haltContract();
        vm.stopPrank();

        vm.startPrank(userOne);
        err = abi.encodeWithSignature("MantleTokenMigrator_OnlyWhenNotHalted()");
        vm.expectRevert(err);
        mantleTokenMigrator.migrateAllBIT();
        vm.stopPrank();
    }

    function test_migrateAllBIT() public {
        vm.startPrank(userOne);

        // should fail if the users approve amount is not enough
        err = bytes("TRANSFER_FROM_FAILED");
        vm.expectRevert(err);
        mantleTokenMigrator.migrateAllBIT();

        // approve mantleTokenMigrator
        tokenOne.approve(address(mantleTokenMigrator), 10000 ether);

        // should fail when the contract is not funded
        err = bytes("TRANSFER_FAILED");
        vm.expectRevert(err);
        mantleTokenMigrator.migrateAllBIT();
        vm.stopPrank();

        // fund contract with tokenTwo
        _fundContractWithTokenTwo();

        // assert that the contract has the correct amount of tokenTwo after being funded
        assertEq(tokenTwo.balanceOf(address(mantleTokenMigrator)), 42069 ether);

        // swap all BIT
        vm.startPrank(userOne);
        mantleTokenMigrator.migrateAllBIT();
        vm.stopPrank();

        // assert that the contract/user have the correct amount of tokenTwo after the user has swapped all tokenOne
        assertEq(tokenTwo.balanceOf(address(mantleTokenMigrator)), 0 ether);
        assertEq(tokenTwo.balanceOf(userOne), 42069 ether);

        // assert that the contract/user have the correct amount of tokenOne after the user has swapped all tokenOne
        assertEq(tokenOne.balanceOf(address(mantleTokenMigrator)), 10000 ether);
        assertEq(tokenOne.balanceOf(userOne), 0 ether);
    }

    function test_migrateBIT() public {
        vm.startPrank(userTwo);

        // should fail if the users approve amount is not enough
        uint256 amountTooLargeToSwap = 100000 ether;

        err = bytes("TRANSFER_FROM_FAILED");
        vm.expectRevert(err);
        mantleTokenMigrator.migrateBIT(amountTooLargeToSwap);

        // approve mantleTokenMigrator
        tokenOne.approve(address(mantleTokenMigrator), amountTooLargeToSwap);

        // should fail if the user doesn't have the correct tokenOne balance
        err = bytes("TRANSFER_FROM_FAILED");
        vm.expectRevert(err);
        mantleTokenMigrator.migrateBIT(amountTooLargeToSwap);

        // should fail when the contract is not funded
        uint256 amountToSwap = 5000 ether;
        err = bytes("TRANSFER_FAILED");
        vm.expectRevert(err);
        mantleTokenMigrator.migrateBIT(amountToSwap);
        vm.stopPrank();

        // fund contract with tokenTwo
        _fundContractWithTokenTwo();

        // assert that the contract has the correct amount of tokenTwo after being funded
        assertEq(tokenTwo.balanceOf(address(mantleTokenMigrator)), 42069 ether);

        // swap half of the users TokenOne
        vm.startPrank(userTwo);
        mantleTokenMigrator.migrateBIT(amountToSwap);
        vm.stopPrank();

        // assert that the contract/user have the correct amount of tokenTwo after the user has swapped all tokenOne
        assertEq(tokenTwo.balanceOf(address(mantleTokenMigrator)), (210345 ether) / 10);
        assertEq(tokenTwo.balanceOf(userTwo), (210345 ether) / 10);

        // assert that the contract/user have the correct amount of tokenOne after the user has swapped half their tokenOne
        assertEq(tokenOne.balanceOf(address(mantleTokenMigrator)), 5000 ether);
        assertEq(tokenOne.balanceOf(userTwo), 5000 ether);

        // swap other half of the users TokenOne
        vm.startPrank(userTwo);
        mantleTokenMigrator.migrateBIT(amountToSwap);
        vm.stopPrank();

        // assert that the contract/user have the correct amount of tokenTwo after the user has swapped all tokenOne
        assertEq(tokenTwo.balanceOf(address(mantleTokenMigrator)), 0);
        assertEq(tokenTwo.balanceOf(userTwo), 42069 ether);

        // assert that the contract/user have the correct amount of tokenOne after the user has swapped half their tokenOne
        assertEq(tokenOne.balanceOf(address(mantleTokenMigrator)), 10000 ether);
        assertEq(tokenOne.balanceOf(userTwo), 0 ether);
    }

    function test_sweepTokensERC20() public {
        // send tokenToSweep to the contract
        vm.startPrank(userThree);
        tokenToSweep.transfer(address(mantleTokenMigrator), 1000 ether);
        vm.stopPrank();

        // assert that the contract has the correct amount of tokenToSweep after being funded
        assertEq(tokenToSweep.balanceOf(address(mantleTokenMigrator)), 1000 ether);
        assertEq(tokenToSweep.balanceOf(userThree), 9000 ether);

        // make sure that an address that is not the contract owner can sweep tokens
        err = abi.encodeWithSignature("MantleTokenMigrator_OnlyOwner(address)", address(this));
        vm.expectRevert(err);
        mantleTokenMigrator.sweepTokens(address(tokenToSweep), userThree, 1000 ether);

        // make sure that the contract owner can sweep tokens
        vm.startPrank(deployer);
        mantleTokenMigrator.sweepTokens(address(tokenToSweep), userThree, 1000 ether);

        // assert balances are correct post sweep
        assertEq(tokenToSweep.balanceOf(address(mantleTokenMigrator)), 0 ether);
        assertEq(tokenToSweep.balanceOf(userThree), 10000 ether);

        // assert that trying to sweep tokenOne fails
        err = abi.encodeWithSignature("MantleTokenMigrator_SweepNotAllowed(address)", address(tokenOne));
        vm.expectRevert(err);
        mantleTokenMigrator.sweepTokens(address(tokenOne), userThree, 1000 ether);

        // assert that trying to sweep tokenTwo fails
        err = abi.encodeWithSignature("MantleTokenMigrator_SweepNotAllowed(address)", address(tokenTwo));
        vm.expectRevert(err);
        mantleTokenMigrator.sweepTokens(address(tokenTwo), userThree, 1000 ether);
        vm.stopPrank();
    }

    function test_defundContract() public {
        // assert that a non owner address cannot fund the contract
        err = abi.encodeWithSignature("MantleTokenMigrator_OnlyOwner(address)", address(this));
        vm.expectRevert(err);
        mantleTokenMigrator.defundContract(address(tokenTwo), 1000 ether);

        vm.startPrank(deployer);
        // assert that we are only able to defund the contract of valid tokens
        err = abi.encodeWithSignature("MantleTokenMigrator_InvalidFundingToken(address)", address(tokenToSweep));
        vm.expectRevert(err);
        mantleTokenMigrator.defundContract(address(tokenToSweep), 1000 ether);

        // check that we error out if the contract is not sufficiently funded
        err = bytes("TRANSFER_FAILED");
        vm.expectRevert(err);
        mantleTokenMigrator.defundContract(address(tokenOne), 1000 ether);

        vm.stopPrank();

        // fund the contract
        _fundContractWithTokenTwo();

        // perform a swap
        vm.startPrank(userOne);
        tokenOne.approve(address(mantleTokenMigrator), 5000 ether);
        mantleTokenMigrator.migrateBIT(5000 ether);
        vm.stopPrank();

        // assert balances are correct
        assertEq(tokenOne.balanceOf(address(mantleTokenMigrator)), 5000 ether);
        assertEq(tokenOne.balanceOf(userOne), 5000 ether);
        assertEq(tokenTwo.balanceOf(address(mantleTokenMigrator)), (210345 ether) / 10);
        assertEq(tokenTwo.balanceOf(userOne), (210345 ether) / 10);

        vm.startPrank(deployer);

        // assert that we can defund the contract
        mantleTokenMigrator.defundContract(address(tokenOne), 1000 ether);
        mantleTokenMigrator.defundContract(address(tokenTwo), 1000 ether);

        // assert that the balances are correct
        assertEq(tokenOne.balanceOf(address(mantleTokenMigrator)), 4000 ether);
        assertEq(tokenOne.balanceOf(treasury), 1000 ether);
        assertEq(tokenTwo.balanceOf(address(mantleTokenMigrator)), (210345 ether) / 10 - 1000 ether);
        assertEq(tokenTwo.balanceOf(treasury), 42069 ether + 1000 ether);
    }

    function test_transferOwnership() public {
        // assert that an address that is not the owner can't transfer ownership
        err = abi.encodeWithSignature("MantleTokenMigrator_OnlyOwner(address)", address(this));
        vm.expectRevert(err);
        mantleTokenMigrator.transferOwnership(userOne);

        vm.startPrank(deployer);

        // assert that the deployer is able to transfer ownership
        mantleTokenMigrator.transferOwnership(userOne);

        vm.stopPrank();

        // assert that the new owner is set in storage
        assertEq(mantleTokenMigrator.owner(), userOne);

        // assert that the new owner is able to transfer ownership
        vm.startPrank(userOne);

        mantleTokenMigrator.transferOwnership(userTwo);

        vm.stopPrank();

        // assert that the new owner is set in storage
        assertEq(mantleTokenMigrator.owner(), userTwo);
    }

    function test_haltContract() public {
        // assert contract is not halted
        assertEq(mantleTokenMigrator.halted(), false);

        // halt the contract
        vm.startPrank(deployer);
        mantleTokenMigrator.haltContract();
        vm.stopPrank();

        // assert contract is halted
        assertEq(mantleTokenMigrator.halted(), true);
    }

    function test_setTreasury() public {
        // assert that the treasury is set to the initialized value
        assertEq(mantleTokenMigrator.treasury(), treasury);

        // assert that the treasury can't be set by a non-owner address
        err = abi.encodeWithSignature("MantleTokenMigrator_OnlyOwner(address)", address(this));
        vm.expectRevert(err);
        mantleTokenMigrator.setTreasury(userOne);

        // become the deployer
        vm.startPrank(deployer);

        // assert that the treasury can be set by the owner
        mantleTokenMigrator.setTreasury(userOne);
        assertEq(mantleTokenMigrator.treasury(), userOne);

        vm.stopPrank();
    }

    function test_fallback() public {
        // assert that the fallback function reverts when a function that doesn't exist is called
        bytes memory messageData = bytes("absolutely invalid message data");
        err = abi.encodeWithSignature("MantleTokenMigrator_InvalidMessageData(bytes)", messageData);
        vm.expectRevert(err);
        (bool success,) = address(mantleTokenMigrator).call{value: 1}(messageData);
        assertTrue(success, "expectRevert: call did not revert");
    }

    function test_receive() public {
        // assert that the receive function reverts when ether is sent to the contract
        err = abi.encodeWithSignature("MantleTokenMigrator_EthNotAccepted()");
        vm.expectRevert(err);
        (bool success,) = address(mantleTokenMigrator).call{value: 1}("");
        assertTrue(success, "expectRevert: call did not revert");
    }

    function _fundContractWithTokenTwo() internal {
        // fund the contract
        vm.startPrank(treasury);
        tokenTwo.transfer(address(mantleTokenMigrator), 42069 ether);
        vm.stopPrank();
    }
}
