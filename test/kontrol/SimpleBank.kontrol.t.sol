// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SimpleBank} from "../../src/SimpleBank.sol";

/// @notice Receiver whose `receive` reverts, so `transfer` from the bank fails.
contract KontrolRejector {
    SimpleBank internal immutable BANK;

    constructor(SimpleBank bank) {
        BANK = bank;
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

/// @notice Kontrol proofs of SimpleBank. Each test is one symbolic claim.
///         `value` is capped so the KEVM search stays finite in practice.
contract SimpleBankKontrolTest is Test {
    uint256 internal constant CAP = 10 ether;

    receive() external payable {}

    function test_p1_deposit(uint96 value) external {
        vm.assume(value > 0 && value < CAP);
        vm.deal(address(this), value);
        SimpleBank bank = new SimpleBank();

        bank.deposit{value: value}();

        assertEq(bank.balances(address(this)), value);
        assertEq(address(bank).balance, value);
    }

    function test_p2_withdraw(uint96 value) external {
        vm.assume(value > 0 && value < CAP);
        vm.deal(address(this), value);
        SimpleBank bank = new SimpleBank();
        bank.deposit{value: value}();
        uint256 held = address(this).balance;

        bank.withdraw(value);

        assertEq(bank.balances(address(this)), 0);
        assertEq(address(bank).balance, 0);
        assertEq(address(this).balance, held + value);
    }

    function test_p2_withdraw_short_reverts() external {
        SimpleBank bank = new SimpleBank();
        (bool ok,) = address(bank).call(abi.encodeCall(SimpleBank.withdraw, (1)));
        assertFalse(ok);
        assertEq(bank.balances(address(this)), 0);
        assertEq(address(bank).balance, 0);
    }

    function test_p3_other_credit_untouched(uint96 value) external {
        vm.assume(value > 0 && value < CAP);
        vm.deal(address(this), value);
        SimpleBank bank = new SimpleBank();
        address other = address(0xBEEF);

        bank.deposit{value: value}();

        assertEq(bank.balances(other), 0);
        assertEq(bank.balances(address(this)), value);
    }

    function test_p4_solvent_after_deposit(uint96 value) external {
        vm.assume(value > 0 && value < CAP);
        vm.deal(address(this), value);
        SimpleBank bank = new SimpleBank();

        bank.deposit{value: value}();

        assertEq(bank.balances(address(this)), address(bank).balance);
    }

    function test_p5_rejector_reverts(uint96 value) external {
        vm.assume(value > 0 && value < CAP);
        vm.deal(address(this), value);
        SimpleBank bank = new SimpleBank();
        KontrolRejector rejector = new KontrolRejector(bank);

        rejector.deposit{value: value}();
        assertEq(bank.balances(address(rejector)), value);

        (bool ok,) = address(rejector).call(abi.encodeCall(KontrolRejector.withdraw, (value)));
        assertFalse(ok);
        assertEq(bank.balances(address(rejector)), value);
        assertEq(address(bank).balance, value);
    }
}
