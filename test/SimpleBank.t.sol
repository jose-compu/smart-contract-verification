// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SimpleBank} from "../src/SimpleBank.sol";

contract RevertingReceiver {
    SimpleBank public immutable BANK;

    constructor(SimpleBank bank_) {
        BANK = bank_;
    }

    function deposit() external payable {
        BANK.deposit{value: msg.value}();
    }

    function withdraw(uint256 amount) external {
        BANK.withdraw(amount);
    }

    receive() external payable {
        revert("reject");
    }
}

contract ExpensiveReceiver {
    SimpleBank public immutable BANK;
    uint256 public n;

    constructor(SimpleBank bank_) {
        BANK = bank_;
    }

    function deposit() external payable {
        BANK.deposit{value: msg.value}();
    }

    function withdraw(uint256 amount) external {
        BANK.withdraw(amount);
    }

    receive() external payable {
        // Exceeds the 2,300-gas stipend forwarded by `transfer`.
        for (uint256 i = 0; i < 50; ++i) {
            n += 1;
        }
    }
}

contract SimpleBankTest is Test {
    SimpleBank internal bank;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        bank = new SimpleBank();
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function test_DepositCreditsCallerAndIncreasesReserves() public {
        vm.prank(alice);
        bank.deposit{value: 1 ether}();

        assertEq(bank.balances(alice), 1 ether);
        assertEq(address(bank).balance, 1 ether);
    }

    function test_DepositZeroIsNoOp() public {
        vm.prank(alice);
        bank.deposit{value: 0}();

        assertEq(bank.balances(alice), 0);
        assertEq(address(bank).balance, 0);
    }

    function test_DepositsAccumulatePerUser() public {
        vm.prank(alice);
        bank.deposit{value: 1 ether}();
        vm.prank(alice);
        bank.deposit{value: 2 ether}();
        vm.prank(bob);
        bank.deposit{value: 3 ether}();

        assertEq(bank.balances(alice), 3 ether);
        assertEq(bank.balances(bob), 3 ether);
        assertEq(address(bank).balance, 6 ether);
    }

    function test_WithdrawPaysCallerAndDecreasesCredit() public {
        vm.prank(alice);
        bank.deposit{value: 5 ether}();

        uint256 aliceBefore = alice.balance;
        vm.prank(alice);
        bank.withdraw(2 ether);

        assertEq(bank.balances(alice), 3 ether);
        assertEq(alice.balance, aliceBefore + 2 ether);
        assertEq(address(bank).balance, 3 ether);
    }

    function test_WithdrawEntireBalance() public {
        vm.prank(alice);
        bank.deposit{value: 4 ether}();

        vm.prank(alice);
        bank.withdraw(4 ether);

        assertEq(bank.balances(alice), 0);
        assertEq(address(bank).balance, 0);
        assertEq(alice.balance, 100 ether);
    }

    function test_WithdrawZeroIsNoOp() public {
        vm.prank(alice);
        bank.deposit{value: 1 ether}();

        uint256 aliceBefore = alice.balance;
        vm.prank(alice);
        bank.withdraw(0);

        assertEq(bank.balances(alice), 1 ether);
        assertEq(alice.balance, aliceBefore);
        assertEq(address(bank).balance, 1 ether);
    }

    function test_WithdrawRevertsWhenAmountExceedsCredit() public {
        vm.prank(alice);
        bank.deposit{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert();
        bank.withdraw(1 ether + 1);
    }

    function test_WithdrawRevertsWhenCallerHasNoCredit() public {
        vm.prank(alice);
        vm.expectRevert();
        bank.withdraw(1);
    }

    function test_CallerCannotWithdrawAnotherUsersCredit() public {
        vm.prank(alice);
        bank.deposit{value: 2 ether}();

        vm.prank(bob);
        vm.expectRevert();
        bank.withdraw(1 ether);

        assertEq(bank.balances(alice), 2 ether);
        assertEq(bank.balances(bob), 0);
        assertEq(address(bank).balance, 2 ether);
    }

    function test_PlainEtherTransferToBankReverts() public {
        vm.prank(alice);
        vm.expectRevert();
        payable(address(bank)).transfer(1 ether);
    }

    function test_EmptyCalldataReverts() public {
        (bool ok,) = address(bank).call("");
        assertFalse(ok);
    }

    function test_UnknownSelectorReverts() public {
        (bool ok,) = address(bank).call(hex"deadbeef");
        assertFalse(ok);
    }

    function test_WithdrawWithValueReverts() public {
        vm.prank(alice);
        bank.deposit{value: 1 ether}();

        vm.prank(alice);
        (bool ok,) = address(bank).call{value: 1}(abi.encodeCall(SimpleBank.withdraw, (1 ether)));
        assertFalse(ok);
        assertEq(bank.balances(alice), 1 ether);
    }

    function test_WithdrawRevertsWhenReceiverRejectsEther() public {
        RevertingReceiver receiver = new RevertingReceiver(bank);
        receiver.deposit{value: 1 ether}();

        vm.expectRevert();
        receiver.withdraw(1 ether);

        assertEq(bank.balances(address(receiver)), 1 ether);
        assertEq(address(bank).balance, 1 ether);
    }

    function test_WithdrawRevertsWhenReceiverConsumesMoreThanTransferStipend() public {
        ExpensiveReceiver receiver = new ExpensiveReceiver(bank);
        receiver.deposit{value: 1 ether}();

        vm.expectRevert();
        receiver.withdraw(1 ether);

        assertEq(bank.balances(address(receiver)), 1 ether);
    }

    function test_ExpensiveReceiverLoopCompletesOnDirectTransfer() public {
        ExpensiveReceiver receiver = new ExpensiveReceiver(bank);
        (bool ok,) = address(receiver).call{value: 1 wei}("");
        assertTrue(ok);
        assertEq(receiver.n(), 50);
    }

    function testFuzz_DepositCreditsExactValue(uint96 amount) public {
        vm.deal(alice, amount);
        vm.prank(alice);
        bank.deposit{value: amount}();

        assertEq(bank.balances(alice), amount);
        assertEq(address(bank).balance, amount);
    }

    function testFuzz_WithdrawWithinCredit(uint96 depositAmount, uint96 withdrawAmount) public {
        vm.assume(withdrawAmount <= depositAmount);
        vm.deal(alice, depositAmount);

        vm.prank(alice);
        bank.deposit{value: depositAmount}();

        uint256 aliceBefore = alice.balance;
        vm.prank(alice);
        bank.withdraw(withdrawAmount);

        assertEq(bank.balances(alice), uint256(depositAmount) - withdrawAmount);
        assertEq(alice.balance, aliceBefore + withdrawAmount);
        assertEq(address(bank).balance, uint256(depositAmount) - withdrawAmount);
    }

    function testFuzz_WithdrawAboveCreditReverts(uint96 depositAmount, uint256 withdrawAmount) public {
        withdrawAmount = bound(withdrawAmount, uint256(depositAmount) + 1, type(uint256).max);
        vm.deal(alice, depositAmount);

        vm.prank(alice);
        bank.deposit{value: depositAmount}();

        vm.prank(alice);
        vm.expectRevert();
        bank.withdraw(withdrawAmount);
    }

    function testFuzz_IndependentAccounting(uint96 aliceAmount, uint96 bobAmount) public {
        vm.deal(alice, aliceAmount);
        vm.deal(bob, bobAmount);

        vm.prank(alice);
        bank.deposit{value: aliceAmount}();
        vm.prank(bob);
        bank.deposit{value: bobAmount}();

        assertEq(bank.balances(alice), aliceAmount);
        assertEq(bank.balances(bob), bobAmount);
        assertEq(address(bank).balance, uint256(aliceAmount) + bobAmount);
    }
}
