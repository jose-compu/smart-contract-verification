// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {SimpleBank} from "../../src/SimpleBank.sol";

/// @notice Halmos symbolic tests for SimpleBank, compiled under FOUNDRY_PROFILE=halmos.
/// @dev `svm.createAddress`/`createUint*` produce genuinely symbolic values (unlike a Foundry
/// fuzz argument, which is a *typed* input still drawn from a concrete distribution). Reverts are
/// observed with `try`/`catch`: halmos does not implement `vm.expectRevert`, so that cheatcode
/// would silently no-op instead of asserting anything.
contract SimpleBankHalmosTest is SymTest, Test {
    SimpleBank internal bank;

    function setUp() public {
        bank = new SimpleBank();
    }

    // P1: deposit of `amount` credits the caller and the vault's ETH by exactly `amount`.
    function check_Deposit_CreditsCallerAndReserves(uint96 amount) public {
        address caller = svm.createAddress("caller");
        vm.assume(caller != address(bank));
        vm.deal(caller, amount);

        uint256 creditBefore = bank.balances(caller);
        uint256 reservesBefore = address(bank).balance;

        vm.prank(caller);
        bank.deposit{value: amount}();

        assert(bank.balances(caller) == creditBefore + amount);
        assert(address(bank).balance == reservesBefore + amount);
    }

    // P2a: withdraw reverts when the caller's credit is short, and leaves it unchanged.
    function check_Withdraw_RevertsWhenCreditShort(uint256 credit, uint256 amount) public {
        address caller = svm.createAddress("caller");
        vm.assume(caller != address(bank));
        vm.assume(credit < amount);
        vm.deal(caller, credit);

        vm.prank(caller);
        bank.deposit{value: credit}();

        vm.prank(caller);
        try bank.withdraw(amount) {
            assert(false);
        } catch {
            assert(bank.balances(caller) == credit);
        }
    }

    // P2b: a successful withdraw debits the caller by exactly `amount` and pays them that much.
    function check_Withdraw_SuccessDebitsCaller(uint256 credit, uint256 amount) public {
        address caller = svm.createAddress("caller");
        vm.assume(caller != address(bank));
        vm.deal(caller, credit);

        vm.prank(caller);
        bank.deposit{value: credit}();

        uint256 callerEthBefore = caller.balance;

        vm.prank(caller);
        try bank.withdraw(amount) {
            assert(amount <= credit);
            assert(bank.balances(caller) == credit - amount);
            assert(caller.balance == callerEthBefore + amount);
        } catch {
            // Credit was short; covered by check_Withdraw_RevertsWhenCreditShort.
        }
    }

    // P3a: a deposit never changes any other address's credit.
    function check_Deposit_PreservesOtherCredit(uint96 amount) public {
        address caller = svm.createAddress("caller");
        address other = svm.createAddress("other");
        vm.assume(caller != other);
        vm.deal(caller, amount);

        uint256 otherBefore = bank.balances(other);

        vm.prank(caller);
        bank.deposit{value: amount}();

        assert(bank.balances(other) == otherBefore);
    }

    // P3b: a withdraw, whether it succeeds or reverts, never changes any other address's credit.
    function check_Withdraw_PreservesOtherCredit(uint256 credit, uint256 amount) public {
        address caller = svm.createAddress("caller");
        address other = svm.createAddress("other");
        vm.assume(caller != other);
        vm.deal(caller, credit);

        vm.prank(caller);
        bank.deposit{value: credit}();

        uint256 otherBefore = bank.balances(other);

        vm.prank(caller);
        try bank.withdraw(amount) {} catch {}

        assert(bank.balances(other) == otherBefore);
    }

    // P5: a withdraw that reverts because the receiver rejects ETH leaves the caller's credit
    // unchanged (revert atomicity), mirroring the Certora Rejector harness with a real contract.
    function check_Withdraw_RevertOnRejectingReceiverLeavesCreditUnchanged(uint96 credit, uint256 amount) public {
        vm.assume(amount <= credit);

        RejectingReceiver receiver = new RejectingReceiver(bank);
        vm.deal(address(receiver), credit);
        receiver.deposit(credit);

        uint256 creditBefore = bank.balances(address(receiver));

        assert(!receiver.withdraw(amount));
        assert(bank.balances(address(receiver)) == creditBefore);
    }
}

contract RejectingReceiver {
    SimpleBank internal immutable BANK;

    constructor(SimpleBank bank_) {
        BANK = bank_;
    }

    function deposit(uint256 amount) external {
        BANK.deposit{value: amount}();
    }

    function withdraw(uint256 amount) external returns (bool ok) {
        (ok,) = address(BANK).call(abi.encodeCall(SimpleBank.withdraw, (amount)));
    }

    receive() external payable {
        revert("reject");
    }
}
