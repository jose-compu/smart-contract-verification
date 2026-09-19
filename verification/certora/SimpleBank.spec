// Certora CVL spec for src/SimpleBank.sol
// https://docs.certora.com/
//
// Rules are checked against compiled bytecode. This is not a Lean model and
// not an EVM interpreter written by hand: the Prover symbolically executes
// the solc output.
//
// `transfer` is an unresolved CALL. The Prover may havoc ETH balances on that
// path, so withdraw rules assert credit accounting and revert behaviour, not
// a precise native-balance delta.

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

function isEoa(env e) returns bool {
    return e.msg.sender != currentContract
        && e.msg.sender != rejector
        && e.msg.sender == e.tx.origin
        && nativeCodesize[e.msg.sender] == 0;
}

function noUintOverflow(uint256 a, uint256 b) returns bool {
    return to_mathint(a) + to_mathint(b) <= max_uint256;
}

// P1: deposit of v increases the caller's credit and the vault's ETH by v.
rule P1_deposit_credits_caller_and_reserves(env e) {
    require isEoa(e);
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

// P2b: if withdraw returns, the caller was debited by amount.
rule P2_withdraw_success_debits_caller(env e, uint256 amount) {
    require e.msg.value == 0;
    require e.msg.sender != currentContract;

    uint256 creditBefore = balances(e.msg.sender);

    withdraw@withrevert(e, amount);

    assert !lastReverted => creditBefore >= amount
        && balances(e.msg.sender) == creditBefore - amount,
        "a successful withdraw must debit the caller by amount";
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

// P4: credits never exceed vault ETH on deposit (constructor may hold extra ETH).
// withdraw is filtered: `transfer` is an unresolved CALL and may havoc ETH.
invariant P4_solvency()
    sumCredits <= nativeBalances[currentContract]
    filtered { f -> f.selector != sig:withdraw(uint256).selector }
{
    preserved with (env e) {
        require e.msg.sender != currentContract;
        require e.msg.sender != rejector;
    }
}

// P4: deposit from an EOA preserves exact sum(credits) == vault ETH when it held.
rule P4_deposit_preserves_equality(env e) {
    require isEoa(e);
    require nativeBalances[e.msg.sender] >= e.msg.value;
    require noUintOverflow(balances(e.msg.sender), e.msg.value);
    require nativeBalances[currentContract] + e.msg.value <= max_uint256;
    require sumCredits == nativeBalances[currentContract];

    deposit(e);

    assert sumCredits == nativeBalances[currentContract],
        "deposit from an EOA must preserve solvency equality";
}

// P4: a reverting withdraw leaves the credit ghost unchanged.
rule P4_withdraw_revert_preserves_credit_sum(env e, uint256 amount) {
    require e.msg.value == 0;

    mathint sumBefore = sumCredits;

    withdraw@withrevert(e, amount);

    assert lastReverted => sumCredits == sumBefore,
        "a reverting withdraw must leave the credit sum unchanged";
}

invariant P4_credit_le_sum(address a)
    to_mathint(balances(a)) <= sumCredits
    filtered { f -> f.selector != sig:withdraw(uint256).selector }
{
    preserved with (env e) {
        require e.msg.sender != currentContract;
        require e.msg.sender != rejector;
    }
}

// P5: if withdraw reverts (insufficient credit, rejected transfer, or CALL
// failure), the caller's credit is unchanged. The Prover does not execute
// `Rejector.receive` on `transfer`, so "must revert" is not asserted.
rule P5_withdraw_revert_preserves_credit(env e, uint256 amount) {
    require e.msg.value == 0;

    uint256 creditBefore = balances(e.msg.sender);

    withdraw@withrevert(e, amount);

    assert lastReverted => balances(e.msg.sender) == creditBefore,
        "a reverting withdraw must leave the caller's credit unchanged";
}
