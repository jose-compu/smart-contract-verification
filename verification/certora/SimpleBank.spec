// Certora CVL spec for src/SimpleBank.sol
// https://docs.certora.com/
//
// Rules are checked against compiled bytecode. This is not a Lean model and
// not an EVM interpreter written by hand: the Prover symbolically executes
// the solc output.

using Rejector as rejector;

methods {
    function balances(address) external returns(uint256) envfree;
    function deposit() external;
    function withdraw(uint256) external;
}

ghost mathint sumCredits {
    init_state axiom sumCredits == 0;
}

hook Sstore balances[KEY address account] uint256 newValue (uint256 oldValue) {
    sumCredits = sumCredits + newValue - oldValue;
}

function isExternalCaller(env e) returns bool {
    return e.msg.sender != currentContract && e.msg.sender != rejector;
}

function noUintOverflow(uint256 a, uint256 b) returns bool {
    return to_mathint(a) + to_mathint(b) <= max_uint256;
}

// P1: deposit of v increases the caller's credit and the vault's ETH by v.
rule P1_deposit_credits_caller_and_reserves(env e) {
    require isExternalCaller(e);
    require nativeBalances[e.msg.sender] >= e.msg.value;
    require noUintOverflow(balances(e.msg.sender), e.msg.value);
    require nativeBalances[currentContract] + e.msg.value <= max_uint256;

    uint256 creditBefore = balances(e.msg.sender);
    mathint reservesBefore = nativeBalances[currentContract];

    deposit(e);

    assert balances(e.msg.sender) == creditBefore + e.msg.value,
        "deposit must credit msg.value to the caller";
    assert nativeBalances[currentContract] == reservesBefore + e.msg.value,
        "deposit must increase the vault ETH balance by msg.value";
}

// P2a: withdraw reverts when the caller's credit is short.
rule P2_withdraw_reverts_when_credit_short(env e, uint256 amount) {
    require e.msg.value == 0;
    require balances(e.msg.sender) < amount;

    withdraw@withrevert(e, amount);

    assert lastReverted,
        "withdraw must revert when credit is insufficient";
}

// P2b: on an EOA with enough credit and vault ETH, withdraw debits and pays.
rule P2_withdraw_success_debits_and_pays(env e, uint256 amount) {
    require e.msg.value == 0;
    require isExternalCaller(e);
    require e.msg.sender == e.tx.origin;
    require balances(e.msg.sender) >= amount;
    require nativeBalances[currentContract] >= to_mathint(amount);
    require nativeBalances[e.msg.sender] + amount <= max_uint256;

    uint256 creditBefore = balances(e.msg.sender);
    mathint reservesBefore = nativeBalances[currentContract];
    mathint senderBefore = nativeBalances[e.msg.sender];

    withdraw(e, amount);

    assert balances(e.msg.sender) == creditBefore - amount,
        "successful withdraw must debit the caller";
    assert nativeBalances[currentContract] == reservesBefore - amount,
        "successful withdraw must decrease vault ETH by amount";
    assert nativeBalances[e.msg.sender] == senderBefore + amount,
        "successful withdraw must pay the caller";
}

// P2c: for an EOA, with vault ETH covering the credit, withdraw iff credit covers amount.
rule P2_eoa_withdraw_iff_credit(env e, uint256 amount) {
    require e.msg.value == 0;
    require isExternalCaller(e);
    require e.msg.sender == e.tx.origin;
    require nativeBalances[currentContract] >= to_mathint(balances(e.msg.sender));
    require nativeBalances[e.msg.sender] + amount <= max_uint256;

    uint256 creditBefore = balances(e.msg.sender);

    withdraw@withrevert(e, amount);

    assert lastReverted <=> creditBefore < amount,
        "EOA withdraw succeeds iff credit covers amount";
}

// P3: a caller cannot decrease another address's credit.
rule P3_deposit_preserves_other(env e, address other) {
    require e.msg.sender != other;

    uint256 otherBefore = balances(other);
    deposit@withrevert(e);

    assert balances(other) == otherBefore,
        "deposit must not change another address's credit";
}

rule P3_withdraw_preserves_other(env e, uint256 amount, address other) {
    require e.msg.sender != other;

    uint256 otherBefore = balances(other);
    withdraw@withrevert(e, amount);

    assert balances(other) == otherBefore,
        "withdraw must not change another address's credit";
}

// P4: if ETH only enters through deposit (no self-call), sum(credits) == vault ETH.
invariant P4_solvency()
    sumCredits == nativeBalances[currentContract]
{
    preserved with (env e) {
        require e.msg.sender != currentContract;
    }
}

invariant P4_credit_le_sum(address a)
    to_mathint(balances(a)) <= sumCredits
{
    preserved with (env e) {
        require e.msg.sender != currentContract;
    }
}

// P5: withdraw to a contract that rejects ETH reverts and leaves credits unchanged.
rule P5_rejecting_receiver_reverts(env e, uint256 amount) {
    require e.msg.sender == rejector;
    require e.msg.value == 0;
    require balances(e.msg.sender) >= amount;
    require nativeBalances[currentContract] >= to_mathint(amount);

    uint256 creditBefore = balances(e.msg.sender);
    mathint reservesBefore = nativeBalances[currentContract];

    withdraw@withrevert(e, amount);

    assert lastReverted,
        "withdraw must revert when transfer is rejected";
    assert balances(e.msg.sender) == creditBefore,
        "a rejected withdraw must leave the caller's credit unchanged";
    assert nativeBalances[currentContract] == reservesBefore,
        "a rejected withdraw must leave vault ETH unchanged";
}
