// Alloy 6 model of src/SimpleBank.sol
// Language and analyzer: https://alloytools.org/
//
// Bounded relational model of the vault, not an EVM interpreter.
// Wei is a non-negative Alloy Int (finite bitwidth). A passing `check`
// means no counterexample in the declared scope (accounts, ints, steps).

module SimpleBank

open util/integer

sig Account {}

// Callers whose receive/fallback cannot take ETH from `transfer`
// (revert on receive, or code that exceeds the 2,300-gas stipend).
sig Rejecting in Account {}

one sig Bank {
  var credit: Account -> one Int,
  var reserves: Int
}

fun totalCredit: Int {
  sum a: Account | Bank.credit[a]
}

pred nonnegative {
  Bank.reserves >= 0
  all a: Account | Bank.credit[a] >= 0
}

pred init {
  Bank.reserves = 0
  all a: Account | Bank.credit[a] = 0
}

pred stutter {
  Bank.credit' = Bank.credit
  Bank.reserves' = Bank.reserves
}

pred frameOthers[sender: Account] {
  all other: Account - sender | (Bank.credit)'[other] = Bank.credit[other]
}

// deposit(): payable; credits msg.value. Solidity 0.8 reverts on overflow.
pred deposit[sender: Account, value: Int] {
  value >= 0
  plus[Bank.credit[sender], value] >= Bank.credit[sender]
  plus[Bank.reserves, value] >= Bank.reserves
  (Bank.credit)' = Bank.credit ++ (sender -> plus[Bank.credit[sender], value])
  (Bank.reserves)' = plus[Bank.reserves, value]
  frameOthers[sender]
}

// Successful withdraw: require(credit >= amount) and transfer succeeds.
pred withdraw[sender: Account, amount: Int] {
  amount >= 0
  Bank.credit[sender] >= amount
  sender not in Rejecting
  (Bank.credit)' = Bank.credit ++ (sender -> minus[Bank.credit[sender], amount])
  (Bank.reserves)' = minus[Bank.reserves, amount]
  frameOthers[sender]
}

pred trans {
  stutter
  or (some sender: Account, value: Int | deposit[sender, value])
  or (some sender: Account, amount: Int | withdraw[sender, amount])
}

fact traces {
  init
  always trans
  always Bank.reserves <= 4
  always all a: Account | Bank.credit[a] <= 4
}

// P1 — deposit of v increases the caller's credit and the vault reserves by v.
assert P1_deposit_credits_caller_and_reserves {
  always all sender: Account, value: Int |
    deposit[sender, value] implies
      (Bank.credit)'[sender] = plus[Bank.credit[sender], value]
      and (Bank.reserves)' = plus[Bank.reserves, value]
}

// P2 — withdraw of a succeeds only if credit covers a and the receiver can take ETH.
assert P2_withdraw_requires_credit_and_accepting_receiver {
  always all sender: Account, amount: Int |
    withdraw[sender, amount] implies
      amount >= 0
      and Bank.credit[sender] >= amount
      and sender not in Rejecting
}

// P3 — a caller cannot decrease another address's credit.
assert P3_caller_cannot_debit_another_account {
  always all sender, other: Account, value, amount: Int |
    sender != other implies {
      deposit[sender, value] implies (Bank.credit)'[other] = Bank.credit[other]
      withdraw[sender, amount] implies (Bank.credit)'[other] = Bank.credit[other]
    }
}

assert P3_at_most_one_credit_changes {
  always lone a: Account | (Bank.credit)'[a] != Bank.credit[a]
}

// P4 — if ETH only enters through deposit, sum(credits) == reserves.
assert P4_solvency {
  always Bank.reserves = totalCredit
}

// P5 — withdraw to a rejecting receiver is impossible; their credit never falls.
assert P5_rejecting_receiver_cannot_withdraw {
  always all sender: Rejecting, amount: Int | not withdraw[sender, amount]
}

assert P5_rejecting_credit_never_decreases {
  always all sender: Rejecting | (Bank.credit)'[sender] >= Bank.credit[sender]
}

assert credits_stay_nonnegative {
  always nonnegative
}

pred someDeposit {
  some sender: Account, value: Int | value > 0 and deposit[sender, value]
}

pred someWithdraw {
  some sender: Account, amount: Int | amount > 0 and withdraw[sender, amount]
}

run showDeposit { someDeposit } for 2 Account, 4 Int, 4 steps
run showWithdraw {
  someDeposit
  after someWithdraw
} for 2 Account, 4 Int, 5 steps

check P1_deposit_credits_caller_and_reserves for 2 Account, 4 Int, 5 steps
check P2_withdraw_requires_credit_and_accepting_receiver for 2 Account, 4 Int, 5 steps
check P3_caller_cannot_debit_another_account for 2 Account, 4 Int, 5 steps
check P3_at_most_one_credit_changes for 2 Account, 4 Int, 5 steps
check P4_solvency for 2 Account, 4 Int, 5 steps
check P5_rejecting_receiver_cannot_withdraw for 2 Account, 4 Int, 5 steps
check P5_rejecting_credit_never_decreases for 2 Account, 4 Int, 5 steps
check credits_stay_nonnegative for 2 Account, 4 Int, 5 steps
