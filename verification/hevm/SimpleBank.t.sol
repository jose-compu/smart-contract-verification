// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {StdAssertions} from "forge-std/StdAssertions.sol";
import {Vm} from "forge-std/Vm.sol";
import {SimpleBank} from "../../src/SimpleBank.sol";

/// @notice Receiver whose `receive` always reverts. Used for P5.
contract Rejector {
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

/// @dev Symbolic proofs for `src/SimpleBank.sol` via hevm (`prove_` prefix).
///      https://hevm.dev/ — EVM bytecode, not a Solidity-level fuzzer.
///      Avoids forge-std `Test` (large ctor / chain config) which can make
///      hevm bail during `setUp` on the Linux binary.
contract SimpleBankHevmTest is StdAssertions {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address internal constant alice = address(0xA11CE);

    bool public IS_TEST = true;

    receive() external payable {}

    function _bank() internal returns (SimpleBank) {
        return new SimpleBank();
    }

    /// P1: deposit of `v` increases the caller's credit and vault ETH by `v`.
    function prove_P1_deposit_credits_caller_and_reserves(uint256 value) public {
        SimpleBank bank = _bank();
        vm.deal(alice, value);
        uint256 creditBefore = bank.balances(alice);
        uint256 reservesBefore = address(bank).balance;
        vm.assume(creditBefore <= type(uint256).max - value);

        vm.prank(alice);
        bank.deposit{value: value}();

        assertEq(bank.balances(alice), creditBefore + value);
        assertEq(address(bank).balance, reservesBefore + value);
    }

    /// P2: withdraw reverts when the caller's credit is short.
    function prove_P2_withdraw_reverts_when_credit_short(uint256 credit, uint256 amount) public {
        vm.assume(amount > credit);
        SimpleBank bank = _bank();
        vm.deal(alice, credit);
        if (credit > 0) {
            vm.prank(alice);
            bank.deposit{value: credit}();
        }

        vm.prank(alice);
        try bank.withdraw(amount) {
            assert(false);
        } catch {
            assertEq(bank.balances(alice), credit);
        }
    }

    /// P2: on an EOA with enough credit, withdraw debits and pays.
    function prove_P2_withdraw_success_debits_and_pays(uint256 credit, uint256 amount) public {
        vm.assume(amount <= credit);
        SimpleBank bank = _bank();
        vm.deal(alice, credit);
        vm.prank(alice);
        bank.deposit{value: credit}();

        uint256 aliceBefore = alice.balance;
        uint256 reservesBefore = address(bank).balance;

        vm.prank(alice);
        bank.withdraw(amount);

        assertEq(bank.balances(alice), credit - amount);
        assertEq(alice.balance, aliceBefore + amount);
        assertEq(address(bank).balance, reservesBefore - amount);
    }

    /// P3: deposit does not change another address's credit.
    function prove_P3_deposit_preserves_other(address other, uint256 value) public {
        SimpleBank bank = _bank();
        vm.assume(other != alice);
        vm.assume(other != address(bank));
        uint256 otherBefore = bank.balances(other);
        vm.deal(alice, value);
        vm.prank(alice);
        bank.deposit{value: value}();
        assertEq(bank.balances(other), otherBefore);
    }

    /// P3: withdraw does not change another address's credit.
    function prove_P3_withdraw_preserves_other(address other, uint256 credit, uint256 amount) public {
        SimpleBank bank = _bank();
        vm.assume(other != alice);
        vm.assume(other != address(bank));
        vm.assume(amount <= credit);
        uint256 otherBefore = bank.balances(other);
        vm.deal(alice, credit);
        vm.prank(alice);
        bank.deposit{value: credit}();
        vm.prank(alice);
        bank.withdraw(amount);
        assertEq(bank.balances(other), otherBefore);
    }

    /// P4: a deposit from an EOA preserves sum(credits) == vault ETH when it held.
    function prove_P4_deposit_preserves_solvency(uint256 value) public {
        SimpleBank bank = _bank();
        vm.assume(bank.balances(alice) == address(bank).balance);
        vm.deal(alice, value);
        vm.prank(alice);
        bank.deposit{value: value}();
        assertEq(bank.balances(alice), address(bank).balance);
    }

    /// P4: a successful EOA withdraw preserves sum(credits) == vault ETH when it held.
    function prove_P4_withdraw_preserves_solvency(uint256 credit, uint256 amount) public {
        vm.assume(amount <= credit);
        SimpleBank bank = _bank();
        vm.deal(alice, credit);
        vm.prank(alice);
        bank.deposit{value: credit}();
        vm.assume(bank.balances(alice) == address(bank).balance);
        vm.prank(alice);
        bank.withdraw(amount);
        assertEq(bank.balances(alice), address(bank).balance);
    }

    /// P5: withdraw to a contract that rejects ETH reverts and leaves credit unchanged.
    function prove_P5_rejecting_receiver_reverts(uint256 amount) public {
        SimpleBank bank = _bank();
        Rejector rejector = new Rejector(bank);
        vm.deal(address(rejector), amount);
        rejector.deposit{value: amount}();
        uint256 creditBefore = bank.balances(address(rejector));
        uint256 reservesBefore = address(bank).balance;

        try rejector.withdraw(amount) {
            assert(false);
        } catch {
            assertEq(bank.balances(address(rejector)), creditBefore);
            assertEq(address(bank).balance, reservesBefore);
        }
    }
}
