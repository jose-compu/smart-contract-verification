/-
  Survey properties P1-P5 for `src/SimpleBank.sol`, executed on the EVMYulLean EVM.

  Keccak-256 is a foreign function, so these run as a `lake exe` binary rather than
  as `#eval` or kernel-reduced proofs. See README.md for what that does and does not buy.
-/

import SimpleBankEVM

open EvmYul SimpleBankEVM

/-- Turn an interpreter halt into a readable failure rather than a silent pass. -/
def halted (e : EVM.ExecutionException) : String :=
  s!"interpreter halted: {(repr e).pretty}"

/-- Assert `cond`, reporting `detail` either way. -/
def expect (cond : Bool) (detail : String) : Except String String :=
  if cond then .ok detail else .error detail

/-! ## P1: deposit credits the caller and the reserves -/

def p1 : Except String String := do
  let v := wei ether
  let o ← (deposit genesis alice v).mapError halted
  let credit := creditOf o.post alice
  let vault := balanceOf o.post bank
  let sender := balanceOf o.post alice
  expect
    (o.succeeded && credit == ether && vault == ether && sender == 9 * ether)
    s!"returned={o.succeeded} credit={credit} vault={vault} alice={sender}"

/-! ## P2: withdraw succeeds exactly when the credit covers the amount -/

def p2Short : Except String String := do
  let funded ← (deposit genesis alice (wei ether)).mapError halted
  let o ← (withdraw funded.post alice (wei (2 * ether))).mapError halted
  let credit := creditOf o.post alice
  let vault := balanceOf o.post bank
  expect
    (!o.succeeded && credit == ether && vault == ether)
    s!"returned={o.succeeded} credit={credit} vault={vault}"

def p2Exact : Except String String := do
  let funded ← (deposit genesis alice (wei ether)).mapError halted
  let o ← (withdraw funded.post alice (wei ether)).mapError halted
  let credit := creditOf o.post alice
  let vault := balanceOf o.post bank
  let sender := balanceOf o.post alice
  expect
    (o.succeeded && credit == 0 && vault == 0 && sender == 10 * ether)
    s!"returned={o.succeeded} credit={credit} vault={vault} alice={sender}"

def p2Partial : Except String String := do
  let funded ← (deposit genesis alice (wei (2 * ether))).mapError halted
  let o ← (withdraw funded.post alice (wei ether)).mapError halted
  let credit := creditOf o.post alice
  let vault := balanceOf o.post bank
  let sender := balanceOf o.post alice
  expect
    (o.succeeded && credit == ether && vault == ether && sender == 9 * ether)
    s!"returned={o.succeeded} credit={credit} vault={vault} alice={sender}"

def p2Zero : Except String String := do
  let o ← (withdraw genesis alice (wei 0)).mapError halted
  expect
    (o.succeeded && creditOf o.post alice == 0)
    s!"returned={o.succeeded} credit={creditOf o.post alice}"

/-! ## P3: no cross-account interference -/

def p3Deposit : Except String String := do
  let funded ← (deposit genesis bob (wei (3 * ether))).mapError halted
  let o ← (deposit funded.post alice (wei ether)).mapError halted
  expect
    (o.succeeded && creditOf o.post bob == 3 * ether && creditOf o.post alice == ether)
    s!"bob={creditOf o.post bob} alice={creditOf o.post alice}"

def p3Withdraw : Except String String := do
  let fundedBob ← (deposit genesis bob (wei (3 * ether))).mapError halted
  let fundedBoth ← (deposit fundedBob.post alice (wei ether)).mapError halted
  let o ← (withdraw fundedBoth.post alice (wei ether)).mapError halted
  expect
    (o.succeeded && creditOf o.post bob == 3 * ether && balanceOf o.post bob == 7 * ether)
    s!"bobCredit={creditOf o.post bob} bobBalance={balanceOf o.post bob}"

/-- A caller with no credit cannot touch another account's funds. -/
def p3NoCredit : Except String String := do
  let funded ← (deposit genesis bob (wei (3 * ether))).mapError halted
  let o ← (withdraw funded.post alice (wei ether)).mapError halted
  expect
    (!o.succeeded && creditOf o.post bob == 3 * ether && balanceOf o.post bank == 3 * ether)
    s!"returned={o.succeeded} bob={creditOf o.post bob} vault={balanceOf o.post bank}"

/-! ## P4: solvency, `sum(credits) = reserves` -/

def p4 : Except String String := do
  let s1 ← (deposit genesis alice (wei (2 * ether))).mapError halted
  let s2 ← (deposit s1.post bob (wei (3 * ether))).mapError halted
  let s3 ← (withdraw s2.post alice (wei ether)).mapError halted
  let s4 ← (withdraw s3.post bob (wei (3 * ether))).mapError halted
  let credits := creditOf s4.post alice + creditOf s4.post bob
  let vault := balanceOf s4.post bank
  expect
    (credits == vault && vault == ether)
    s!"sum(credits)={credits} reserves={vault}"

/-! ## P5: a receiver that rejects ETH cannot withdraw -/

def p5 : Except String String := do
  let funded ← (deposit genesis rejector (wei ether)).mapError halted
  let credited := creditOf funded.post rejector
  let o ← (withdraw funded.post rejector (wei ether)).mapError halted
  expect
    (funded.succeeded && credited == ether && !o.succeeded
      && creditOf o.post rejector == ether && balanceOf o.post bank == ether)
    (s!"deposited={funded.succeeded} credit={credited} withdrawReturned={o.succeeded} " ++
      s!"creditAfter={creditOf o.post rejector} vault={balanceOf o.post bank}")

/-- A receiver that accepts the call but exceeds the 2300 gas stipend also cannot withdraw. -/
def p5GasHog : Except String String := do
  let funded ← (deposit genesis gasHog (wei ether)).mapError halted
  let o ← (withdraw funded.post gasHog (wei ether)).mapError halted
  expect
    (funded.succeeded && !o.succeeded
      && creditOf o.post gasHog == ether && balanceOf o.post bank == ether)
    (s!"deposited={funded.succeeded} withdrawReturned={o.succeeded} " ++
      s!"credit={creditOf o.post gasHog} vault={balanceOf o.post bank}")

/--
  Control for the check above: the same receiver accepts ETH when gas is ample.

  So the withdraw failed because `transfer` forwards only 2300 gas, not because
  the receiver's code is invalid.
-/
def p5GasHogControl : Except String String := do
  let ample ← (callCode genesis alice gasHog gasHogCode (wei 1) ByteArray.empty (wei 100000)).mapError halted
  let stipend ← (callCode genesis alice gasHog gasHogCode (wei 1) ByteArray.empty (wei 2300)).mapError halted
  expect
    (ample.succeeded && !stipend.succeeded)
    s!"with 100000 gas={ample.succeeded}, with 2300 gas={stipend.succeeded}"

/-- The revert is specific to `transfer` failing: the same amount leaves for an EOA. -/
def p5Contrast : Except String String := do
  let funded ← (deposit genesis alice (wei ether)).mapError halted
  let o ← (withdraw funded.post alice (wei ether)).mapError halted
  expect
    (o.succeeded && balanceOf o.post bank == 0)
    s!"returned={o.succeeded} vault={balanceOf o.post bank}"

/-! ## Controls on the harness itself -/

/--
  The `balances(address)` getter agrees with the slot read used by every check above.

  This is what rules out a plausible failure mode: a wrong `creditSlot` would make
  the storage reads self-consistent but disconnected from the contract's own view.
-/
def slotAgreesWithGetter : Except String String := do
  let funded ← (deposit genesis alice (wei (7 * ether))).mapError halted
  let got ← (balancesGetter funded.post bob alice).mapError halted
  let viaGetter := decodeWord got.output
  let viaSlot := creditOf funded.post alice
  expect
    (got.succeeded && viaGetter == 7 * ether && viaGetter == viaSlot)
    s!"getter={viaGetter} slot={viaSlot}"

/-- The hex literals decoded to the byte counts they should have. -/
def codeLoaded : Except String String :=
  expect
    (bankRuntime.size == 487 && rejectorCode.size == 3 && gasHogCode.size == 5)
    s!"runtime={bankRuntime.size} rejector={rejectorCode.size} gasHog={gasHogCode.size} bytes"

/-! ## Runner -/

def checks : List (String × Except String String) :=
  [ ("bytecode loaded", codeLoaded)
  , ("balances(address) agrees with the storage slot read", slotAgreesWithGetter)
  , ("P1 deposit credits caller and reserves", p1)
  , ("P2 withdraw reverts when credit is short", p2Short)
  , ("P2 withdraw of the full credit succeeds", p2Exact)
  , ("P2 partial withdraw debits exactly", p2Partial)
  , ("P2 zero withdraw is a no-op that returns", p2Zero)
  , ("P3 deposit leaves another account untouched", p3Deposit)
  , ("P3 withdraw leaves another account untouched", p3Withdraw)
  , ("P3 a creditless caller cannot drain the vault", p3NoCredit)
  , ("P4 sum(credits) tracks the reserves", p4)
  , ("P5 a rejecting receiver cannot withdraw", p5)
  , ("P5 a receiver over the 2300 gas stipend cannot withdraw", p5GasHog)
  , ("P5 that receiver does accept ETH when gas is ample", p5GasHogControl)
  , ("P5 the same withdraw succeeds for an EOA", p5Contrast)
  ]

def main : IO UInt32 := do
  IO.println "SimpleBank on the EVMYulLean EVM semantics"
  IO.println "=========================================="
  let mut failed := 0
  for (name, result) in checks do
    match result with
      | .ok detail =>
        IO.println s!"ok    {name}"
        unless detail.isEmpty do IO.println s!"        {detail}"
      | .error detail =>
        failed := failed + 1
        IO.println s!"FAIL  {name}"
        IO.println s!"        {detail}"
  IO.println "=========================================="
  if failed == 0 then
    IO.println s!"all {checks.length} checks passed"
    return 0
  else
    IO.println s!"{failed} of {checks.length} checks failed"
    return 1
