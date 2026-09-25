// Dafny model of src/SimpleBank.sol.
//
// Automated deductive verification: pre/post and an invariant, compiled to
// Boogie and discharged by Z3. https://dafny.org/
// Abstract vault (credits, reserves, a rejecting set, a payout purse), not an
// EVM interpreter. Wei is nat (unbounded). Solidity uint256 overflow is not
// modelled.

type Address = nat
type Wei = nat

datatype State = State(
  credit: map<Address, Wei>,
  reserves: Wei,
  rejecting: set<Address>,
  held: map<Address, Wei>
)

datatype Result = Success(state: State) | Revert

datatype Op =
  | DepositOp(sender: Address, value: Wei)
  | WithdrawOp(sender: Address, amount: Wei)

function CreditOf(m: map<Address, Wei>, a: Address): Wei {
  if a in m then m[a] else 0
}

function HeldOf(m: map<Address, Wei>, a: Address): Wei {
  if a in m then m[a] else 0
}

function sub(a: Wei, b: Wei): Wei
  requires b <= a
{
  a - b
}

predicate Nodup(xs: seq<Address>) {
  forall i, j :: 0 <= i < j < |xs| ==> xs[i] != xs[j]
}

predicate SupportClosed(m: map<Address, Wei>, xs: seq<Address>) {
  forall a :: a in m.Keys ==> a in xs
}

// sum of credits over a fixed support. Missing keys count as 0.
function CreditSum(m: map<Address, Wei>, xs: seq<Address>): nat
  decreases |xs|
{
  if xs == [] then 0
  else CreditOf(m, xs[0]) + CreditSum(m, xs[1..])
}

predicate Solvent(s: State, support: seq<Address>) {
  Nodup(support)
  && SupportClosed(s.credit, support)
  && s.reserves == CreditSum(s.credit, support)
}

function Init(rejecting: set<Address>): State {
  State(map[], 0, rejecting, map[])
}

// deposit(): credit msg.value to the caller and take the ETH.
function deposit(s: State, sender: Address, value: Wei): State {
  State(
    s.credit[sender := CreditOf(s.credit, sender) + value],
    s.reserves + value,
    s.rejecting,
    s.held
  )
}

// withdraw(amount): require credit, refuse a rejecting receiver, refuse a
// reserve shortfall (transfer would fail), then debit and pay the caller.
function withdraw(s: State, sender: Address, amount: Wei): Result {
  if CreditOf(s.credit, sender) < amount then
    Revert
  else if sender in s.rejecting then
    Revert
  else if s.reserves < amount then
    Revert
  else
    Success(State(
      s.credit[sender := sub(CreditOf(s.credit, sender), amount)],
      sub(s.reserves, amount),
      s.rejecting,
      s.held[sender := HeldOf(s.held, sender) + amount]
    ))
}

function Sender(op: Op): Address {
  match op
  case DepositOp(sender, _) => sender
  case WithdrawOp(sender, _) => sender
}

function Step(s: State, op: Op): State {
  match op
  case DepositOp(sender, value) =>
    deposit(s, sender, value)
  case WithdrawOp(sender, amount) =>
    if withdraw(s, sender, amount).Success? then
      withdraw(s, sender, amount).state
    else
      s
}

function Run(s: State, ops: seq<Op>): State
  decreases |ops|
{
  if ops == [] then s else Run(Step(s, ops[0]), ops[1..])
}

lemma HeadNotInTail(xs: seq<Address>)
  requires 0 < |xs|
  requires Nodup(xs)
  ensures xs[0] !in xs[1..]
{
  forall i | 0 <= i < |xs[1..]|
    ensures xs[1..][i] != xs[0]
  {
    assert xs[1..][i] == xs[i + 1];
  }
}

lemma InTail(sender: Address, xs: seq<Address>)
  requires 0 < |xs|
  requires sender in xs
  requires xs[0] != sender
  ensures sender in xs[1..]
{
  var i :| 0 <= i < |xs| && xs[i] == sender;
  assert 0 < i;
  assert xs[1..][i - 1] == sender;
}

lemma NotInTail(sender: Address, xs: seq<Address>)
  requires 0 < |xs|
  requires sender !in xs
  ensures sender !in xs[1..]
{
}

lemma NodupTail(xs: seq<Address>)
  requires 0 < |xs|
  requires Nodup(xs)
  ensures Nodup(xs[1..])
{
  forall i, j | 0 <= i < j < |xs[1..]|
    ensures xs[1..][i] != xs[1..][j]
  {
    assert xs[1..][i] == xs[i + 1];
    assert xs[1..][j] == xs[j + 1];
  }
}

lemma FrameCredit(m: map<Address, Wei>, sender: Address, v: Wei, other: Address)
  requires sender != other
  ensures CreditOf(m[sender := v], other) == CreditOf(m, other)
{
}

lemma FrameHeld(m: map<Address, Wei>, sender: Address, v: Wei, other: Address)
  requires sender != other
  ensures HeldOf(m[sender := v], other) == HeldOf(m, other)
{
}

lemma CreditSumZero(xs: seq<Address>)
  ensures CreditSum(map[], xs) == 0
  decreases |xs|
{
  if 0 < |xs| {
    CreditSumZero(xs[1..]);
  }
}

lemma CreditSumUnchanged(m: map<Address, Wei>, sender: Address, newVal: Wei, xs: seq<Address>)
  requires sender !in xs
  ensures CreditSum(m[sender := newVal], xs) == CreditSum(m, xs)
  decreases |xs|
{
  if 0 < |xs| {
    assert xs[0] != sender;
    FrameCredit(m, sender, newVal, xs[0]);
    NotInTail(sender, xs);
    CreditSumUnchanged(m, sender, newVal, xs[1..]);
  }
}

lemma CreditLeSum(m: map<Address, Wei>, sender: Address, xs: seq<Address>)
  requires sender in xs
  ensures CreditOf(m, sender) <= CreditSum(m, xs)
  decreases |xs|
{
  if xs[0] == sender {
  } else {
    InTail(sender, xs);
    CreditLeSum(m, sender, xs[1..]);
  }
}

lemma CreditSumReplace(m: map<Address, Wei>, sender: Address, newVal: Wei, xs: seq<Address>)
  requires sender in xs
  requires Nodup(xs)
  ensures CreditSum(m[sender := newVal], xs) == CreditSum(m, xs) - CreditOf(m, sender) + newVal
  decreases |xs|
{
  if xs[0] == sender {
    HeadNotInTail(xs);
    CreditSumUnchanged(m, sender, newVal, xs[1..]);
    var prev := CreditOf(m, sender);
    var rest := CreditSum(m, xs[1..]);
    var sum := CreditSum(m, xs);
    assert sum == prev + rest;
    assert CreditSum(m[sender := newVal], xs) == newVal + rest;
    assert newVal + rest == sum - prev + newVal;
  } else {
    InTail(sender, xs);
    NodupTail(xs);
    CreditSumReplace(m, sender, newVal, xs[1..]);
    FrameCredit(m, sender, newVal, xs[0]);
    var head := CreditOf(m, xs[0]);
    var prev := CreditOf(m, sender);
    var rest := CreditSum(m, xs[1..]);
    var sum := CreditSum(m, xs);
    var rest' := CreditSum(m[sender := newVal], xs[1..]);
    assert sum == head + rest;
    assert rest' == rest - prev + newVal;
    assert CreditSum(m[sender := newVal], xs) == head + rest';
    CreditLeSum(m, sender, xs[1..]);
    assert head + (rest - prev + newVal) == sum - prev + newVal;
  }
}

lemma SupportClosedUpdate(m: map<Address, Wei>, xs: seq<Address>, a: Address, v: Wei)
  requires SupportClosed(m, xs)
  requires a in xs
  ensures SupportClosed(m[a := v], xs)
{
  forall k | k in (m[a := v]).Keys
    ensures k in xs
  {
    if k == a {
    } else {
      assert k in m.Keys;
    }
  }
}

// P1 — deposit of v increases the caller's credit and the reserves by v.
lemma P1_deposit_credits_caller_and_reserves(s: State, sender: Address, value: Wei)
  ensures CreditOf(deposit(s, sender, value).credit, sender) == CreditOf(s.credit, sender) + value
  ensures deposit(s, sender, value).reserves == s.reserves + value
  ensures deposit(s, sender, value).held == s.held
  ensures deposit(s, sender, value).rejecting == s.rejecting
{
}

// P3 — a caller cannot decrease another address's credit.
lemma P3_deposit_preserves_other(s: State, sender: Address, other: Address, value: Wei)
  requires sender != other
  ensures CreditOf(deposit(s, sender, value).credit, other) == CreditOf(s.credit, other)
{
  FrameCredit(s.credit, sender, CreditOf(s.credit, sender) + value, other);
}

lemma P3_deposit_preserves_other_all(s: State, sender: Address, value: Wei)
  ensures forall other :: other != sender ==>
    CreditOf(deposit(s, sender, value).credit, other) == CreditOf(s.credit, other)
{
  forall other | other != sender
    ensures CreditOf(deposit(s, sender, value).credit, other) == CreditOf(s.credit, other)
  {
    P3_deposit_preserves_other(s, sender, other, value);
  }
}

lemma P3_withdraw_preserves_other(s: State, sender: Address, other: Address, amount: Wei, s': State)
  requires withdraw(s, sender, amount) == Success(s')
  requires sender != other
  ensures CreditOf(s'.credit, other) == CreditOf(s.credit, other)
  ensures HeldOf(s'.held, other) == HeldOf(s.held, other)
{
  var prev := CreditOf(s.credit, sender);
  assert amount <= prev;
  FrameCredit(s.credit, sender, sub(prev, amount), other);
  FrameHeld(s.held, sender, HeldOf(s.held, sender) + amount, other);
}

lemma P3_withdraw_preserves_other_all(s: State, sender: Address, amount: Wei, s': State)
  requires withdraw(s, sender, amount) == Success(s')
  ensures forall other :: other != sender ==>
    CreditOf(s'.credit, other) == CreditOf(s.credit, other)
{
  forall other | other != sender
    ensures CreditOf(s'.credit, other) == CreditOf(s.credit, other)
  {
    P3_withdraw_preserves_other(s, sender, other, amount, s');
  }
}

// P2 — on a solvent vault, withdraw succeeds iff the caller can cover `amount`
// and is not a rejecting receiver. The reserve check is then redundant.
lemma P2_withdraw_succeeds_iff(s: State, support: seq<Address>, sender: Address, amount: Wei)
  requires Solvent(s, support)
  requires sender in support
  ensures withdraw(s, sender, amount).Success? <==>
    amount <= CreditOf(s.credit, sender) && sender !in s.rejecting
{
  if amount <= CreditOf(s.credit, sender) && sender !in s.rejecting {
    CreditLeSum(s.credit, sender, support);
    assert amount <= s.reserves;
  }
}

// P2 — a successful withdraw debits the caller, drops reserves, and pays the caller.
lemma P2_withdraw_success_effect(s: State, sender: Address, amount: Wei, s': State)
  requires withdraw(s, sender, amount) == Success(s')
  ensures CreditOf(s'.credit, sender) == CreditOf(s.credit, sender) - amount
  ensures s'.reserves == s.reserves - amount
  ensures HeldOf(s'.held, sender) == HeldOf(s.held, sender) + amount
  ensures s'.rejecting == s.rejecting
{
}

// P5 — a rejecting receiver cannot withdraw. Step leaves the state unchanged.
lemma P5_rejecting_reverts(s: State, sender: Address, amount: Wei)
  requires sender in s.rejecting
  ensures withdraw(s, sender, amount) == Revert
{
}

lemma P5_rejecting_preserves_state(s: State, sender: Address, amount: Wei)
  requires sender in s.rejecting
  ensures Step(s, WithdrawOp(sender, amount)) == s
{
  P5_rejecting_reverts(s, sender, amount);
}

// P4 — deposit preserves solvency on a duplicate-free support that contains the sender.
lemma P4_deposit_preserves_solvency(s: State, support: seq<Address>, sender: Address, value: Wei)
  requires Solvent(s, support)
  requires sender in support
  ensures Solvent(deposit(s, sender, value), support)
{
  var s' := deposit(s, sender, value);
  var prev := CreditOf(s.credit, sender);
  var newVal := prev + value;
  CreditLeSum(s.credit, sender, support);
  CreditSumReplace(s.credit, sender, newVal, support);
  SupportClosedUpdate(s.credit, support, sender, newVal);
  assert s'.credit == s.credit[sender := newVal];
  assert CreditSum(s'.credit, support) == s.reserves - prev + newVal;
  assert s.reserves - prev + newVal == s.reserves + value;
}

// P4 — a successful withdraw preserves solvency on the same support.
lemma P4_withdraw_preserves_solvency(s: State, support: seq<Address>, sender: Address, amount: Wei, s': State)
  requires Solvent(s, support)
  requires sender in support
  requires withdraw(s, sender, amount) == Success(s')
  ensures Solvent(s', support)
{
  var prev := CreditOf(s.credit, sender);
  assert amount <= prev;
  assert amount <= s.reserves;
  var newVal: nat := prev - amount;
  CreditLeSum(s.credit, sender, support);
  CreditSumReplace(s.credit, sender, newVal, support);
  SupportClosedUpdate(s.credit, support, sender, newVal);
  assert s'.credit == s.credit[sender := newVal];
  assert CreditSum(s'.credit, support) == s.reserves - prev + newVal;
  assert s.reserves - prev + newVal == s.reserves - amount;
  assert s'.reserves == s.reserves - amount;
}

lemma P4_init_solvent(rejecting: set<Address>, support: seq<Address>)
  requires Nodup(support)
  ensures Solvent(Init(rejecting), support)
{
  CreditSumZero(support);
}

lemma StepPreservesSolvency(s: State, support: seq<Address>, op: Op)
  requires Solvent(s, support)
  requires Sender(op) in support
  ensures Solvent(Step(s, op), support)
{
  match op {
    case DepositOp(sender, value) =>
      P4_deposit_preserves_solvency(s, support, sender, value);
    case WithdrawOp(sender, amount) =>
      var r := withdraw(s, sender, amount);
      if r.Success? {
        P4_withdraw_preserves_solvency(s, support, sender, amount, r.state);
      }
  }
}

lemma TailSenders(ops: seq<Op>, support: seq<Address>)
  requires 0 < |ops|
  requires forall op :: op in ops ==> Sender(op) in support
  ensures forall op :: op in ops[1..] ==> Sender(op) in support
{
  forall op | op in ops[1..]
    ensures Sender(op) in support
  {
    var i :| 0 <= i < |ops[1..]| && ops[1..][i] == op;
    assert ops[i + 1] == op;
  }
}

lemma P4_run_preserves_solvency(s: State, support: seq<Address>, ops: seq<Op>)
  requires Solvent(s, support)
  requires forall op :: op in ops ==> Sender(op) in support
  ensures Solvent(Run(s, ops), support)
  decreases |ops|
{
  if 0 < |ops| {
    StepPreservesSolvency(s, support, ops[0]);
    TailSenders(ops, support);
    P4_run_preserves_solvency(Step(s, ops[0]), support, ops[1..]);
  }
}

// P4 — every state reachable from the deployed vault is solvent.
lemma P4_reachable_solvent(rejecting: set<Address>, support: seq<Address>, ops: seq<Op>)
  requires Nodup(support)
  requires forall op :: op in ops ==> Sender(op) in support
  ensures Solvent(Run(Init(rejecting), ops), support)
{
  P4_init_solvent(rejecting, support);
  P4_run_preserves_solvency(Init(rejecting), support, ops);
}

// On a reachable state a successful withdraw is covered by the reserves.
lemma P2_reachable_withdraw_within_reserves(
  rejecting: set<Address>,
  support: seq<Address>,
  ops: seq<Op>,
  sender: Address,
  amount: Wei
)
  requires Nodup(support)
  requires sender in support
  requires forall op :: op in ops ==> Sender(op) in support
  requires withdraw(Run(Init(rejecting), ops), sender, amount).Success?
  ensures amount <= Run(Init(rejecting), ops).reserves
{
  var s := Run(Init(rejecting), ops);
  P4_reachable_solvent(rejecting, support, ops);
  P2_withdraw_succeeds_iff(s, support, sender, amount);
  CreditLeSum(s.credit, sender, support);
}

// Pre/post and the solvency invariant, on the same model.
// Inv is maintained by the constructor and by every method.
class Vault {
  var credit: map<Address, Wei>
  var reserves: Wei
  var held: map<Address, Wei>
  const support: seq<Address>
  const rejecting: set<Address>

  function Snapshot(): State
    reads this
  {
    State(credit, reserves, rejecting, held)
  }

  predicate Inv()
    reads this
  {
    Solvent(Snapshot(), support)
  }

  constructor(support0: seq<Address>, rejecting0: set<Address>)
    requires Nodup(support0)
    ensures Inv()
    ensures credit == map[]
    ensures reserves == 0
    ensures held == map[]
    ensures support == support0
    ensures rejecting == rejecting0
  {
    support := support0;
    rejecting := rejecting0;
    credit := map[];
    reserves := 0;
    held := map[];
    new;
    P4_init_solvent(rejecting, support);
  }

  method Deposit(sender: Address, value: Wei)
    requires Inv()
    requires sender in support
    modifies this
    ensures Inv()
    ensures Snapshot() == deposit(old(Snapshot()), sender, value)
    ensures CreditOf(credit, sender) == CreditOf(old(credit), sender) + value
    ensures reserves == old(reserves) + value
    ensures held == old(held)
    ensures forall other :: other != sender ==>
      CreditOf(credit, other) == CreditOf(old(credit), other)
  {
    var s0 := Snapshot();
    var before := if sender in credit then credit[sender] else 0;
    credit := credit[sender := before + value];
    reserves := reserves + value;
    var s1 := Snapshot();
    assert s1 == deposit(s0, sender, value);
    P1_deposit_credits_caller_and_reserves(s0, sender, value);
    P3_deposit_preserves_other_all(s0, sender, value);
    P4_deposit_preserves_solvency(s0, support, sender, value);
  }

  method Withdraw(sender: Address, amount: Wei) returns (ok: bool)
    requires Inv()
    requires sender in support
    modifies this
    ensures Inv()
    ensures ok <==> withdraw(old(Snapshot()), sender, amount).Success?
    ensures ok <==> amount <= CreditOf(old(credit), sender) && sender !in rejecting
    ensures ok ==> CreditOf(credit, sender) == CreditOf(old(credit), sender) - amount
    ensures ok ==> reserves == old(reserves) - amount
    ensures ok ==> HeldOf(held, sender) == HeldOf(old(held), sender) + amount
    ensures !ok ==> credit == old(credit) && reserves == old(reserves) && held == old(held)
    ensures forall other :: other != sender ==>
      CreditOf(credit, other) == CreditOf(old(credit), other)
  {
    var s0 := Snapshot();
    var before := if sender in credit then credit[sender] else 0;
    var heldBefore := if sender in held then held[sender] else 0;
    if amount <= before && sender !in rejecting && amount <= reserves {
      credit := credit[sender := sub(before, amount)];
      reserves := sub(reserves, amount);
      held := held[sender := heldBefore + amount];
      ok := true;
      var s1 := Snapshot();
      assert withdraw(s0, sender, amount) == Success(s1);
      P2_withdraw_succeeds_iff(s0, support, sender, amount);
      P2_withdraw_success_effect(s0, sender, amount, s1);
      P3_withdraw_preserves_other_all(s0, sender, amount, s1);
      P4_withdraw_preserves_solvency(s0, support, sender, amount, s1);
    } else {
      ok := false;
      assert withdraw(s0, sender, amount) == Revert;
      P2_withdraw_succeeds_iff(s0, support, sender, amount);
    }
  }
}
