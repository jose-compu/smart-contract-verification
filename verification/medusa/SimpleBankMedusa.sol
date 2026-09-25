// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import {SimpleBank} from "../../src/SimpleBank.sol";

/// @notice Receiver whose `receive` reverts. `transfer` from the bank cannot pay it.
contract Rejector {
    SimpleBank internal immutable BANK;

    constructor(SimpleBank bank) {
        BANK = bank;
    }

    function deposit() external payable {
        BANK.deposit{value: msg.value}();
    }

    function pull(uint256 amount) external {
        BANK.withdraw(amount);
    }

    function credit() external view returns (uint256) {
        return BANK.balances(address(this));
    }

    receive() external payable {
        revert();
    }
}

/// @notice Medusa assertion and property harness. The harness receives ETH.
///         `Rejector` is the stipend / revert case.
contract SimpleBankMedusa {
    SimpleBank public bank;
    Rejector public rejector;
    uint256 public totalCredits;

    constructor() {
        bank = new SimpleBank();
        rejector = new Rejector(bank);
    }

    receive() external payable {}

    function deposit() external payable {
        uint256 beforeCredit = bank.balances(address(this));
        uint256 beforeReserves = address(bank).balance;
        uint256 beforeSelf = address(this).balance;
        uint256 other = rejector.credit();
        bank.deposit{value: msg.value}();
        assert(bank.balances(address(this)) == beforeCredit + msg.value);
        assert(address(bank).balance == beforeReserves + msg.value);
        assert(address(this).balance == beforeSelf - msg.value);
        assert(rejector.credit() == other);
        totalCredits += msg.value;
        assert(address(bank).balance == totalCredits);
    }

    function withdraw(uint256 amount) external {
        uint256 credit = bank.balances(address(this));
        uint256 reserves = address(bank).balance;
        uint256 selfBefore = address(this).balance;
        uint256 other = rejector.credit();
        if (amount > credit) {
            try bank.withdraw(amount) {
                assert(false);
            } catch {
                assert(bank.balances(address(this)) == credit);
                assert(address(bank).balance == reserves);
                assert(rejector.credit() == other);
            }
        } else {
            bank.withdraw(amount);
            assert(bank.balances(address(this)) == credit - amount);
            assert(address(bank).balance == reserves - amount);
            assert(address(this).balance == selfBefore + amount);
            assert(rejector.credit() == other);
            totalCredits -= amount;
        }
        assert(address(bank).balance == totalCredits);
    }

    function rejectorDeposit() external payable {
        uint256 beforeCredit = bank.balances(address(this));
        uint256 before = rejector.credit();
        uint256 reserves = address(bank).balance;
        uint256 beforeSelf = address(this).balance;
        rejector.deposit{value: msg.value}();
        assert(rejector.credit() == before + msg.value);
        assert(bank.balances(address(this)) == beforeCredit);
        assert(address(bank).balance == reserves + msg.value);
        assert(address(this).balance == beforeSelf - msg.value);
        totalCredits += msg.value;
        assert(address(bank).balance == totalCredits);
    }

    function rejectorWithdraw(uint256 amount) external {
        uint256 credit = rejector.credit();
        uint256 reserves = address(bank).balance;
        uint256 selfBefore = address(this).balance;
        try rejector.pull(amount) {
            assert(false);
        } catch {
            assert(rejector.credit() == credit);
            assert(address(bank).balance == reserves);
            assert(address(this).balance == selfBefore);
        }
        assert(address(bank).balance == totalCredits);
    }

    function property_solvency() external view returns (bool) {
        return address(bank).balance == totalCredits;
    }
}
