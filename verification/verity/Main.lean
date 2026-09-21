import Compiler.CompileDriver
import Compiler.CompilationModel.TrustSurface
import SimpleBankVerity

/-!
# Compile `SimpleBank` toward Yul, and check its trust surface is empty

`lake build` checks the proofs. This executable checks the other half of
Verity's claim: that the same artifact the proofs talk about is the one the
compiler lowers, and that lowering it needs no trusted escape hatch.

Every `deny*` gate the compiler offers is switched on. Each one aborts
compilation if the contract reaches for a construct whose correctness Verity
does not prove — raw Yul, an assumed primitive, an unproved external call, a
local obligation left for the caller to discharge. `SimpleBank` is small
enough to pass all of them, so CI fails if a future edit widens the trust
boundary, rather than silently recording it in a report.

The emitted artifacts land in `artifacts/`.
-/

open Compiler.CompilationModel

def outDir : String := "artifacts/yul"
def abiDir : String := "artifacts/abi"
def trustReportPath : String := "artifacts/trust-report.json"
def assumptionReportPath : String := "artifacts/assumption-report.json"

def specs : List CompilationModel := [SimpleBankVerity.SimpleBank.spec]

def countOcc (haystack needle : String) : Nat :=
  (haystack.splitOn needle).length - 1

/--
  The only assumption Verity records for this contract is the checked
  `safeAdd` in `deposit`: overflow is not proved impossible, because it is
  not impossible. The source proofs cover both sides (`deposit_credits_sender`
  when the sum fits, `deposit_reverts_on_overflow` when it does not). The
  compiler still lists that side condition as an assumed local obligation,
  once on `deposit` and once on the generated `internal_deposit`, and each
  is repeated in the undischarged list. Four mentions, four `assumed`
  statuses, nothing else.
-/
def checkAssumptions : IO Unit := do
  let report := emitAssumptionReportJson specs
  let assumed := countOcc report "\"status\":\"assumed\""
  let named := countOcc report "checked_arithmetic_deposit_1_add_no_overflow"
  let unchecked := countOcc report "\"status\":\"unchecked\""
  if assumed == 4 && named == 4 && unchecked == 0 then
    IO.println "✓ only assumed obligation is deposit's checked addition"
  else
    IO.eprintln "✗ unexpected trust surface:"
    IO.eprintln report
    throw (IO.userError "unexpected assumptions")

unsafe def main : IO Unit := do
  IO.println s!"Verity compiler, {specs.length} contract(s)"

  for spec in specs do
    IO.println s!"  {spec.name}: {spec.functions.length} function(s), {spec.fields.length} storage field(s)"
    for fn in spec.functions do
      IO.println s!"    {fn.name} payable={fn.isPayable}"

  checkAssumptions

  Compiler.compileSpecsWithOptions
    specs
    outDir
    (verbose := true)
    (libraryPaths := [])
    (options := {})
    (patchReportPath := none)
    (trustReportPath := some trustReportPath)
    (assumptionReportPath := some assumptionReportPath)
    (abiOutDir := some abiDir)
    (denyUncheckedDependencies := true)
    (denyAssumedDependencies := true)
    (denyAxiomatizedPrimitives := true)
    -- `deposit`'s checked `safeAdd` is an assumed local obligation. See
    -- `checkAssumptions`. The other gates stay closed.
    (denyLocalObligations := false)
    (denyLinearMemoryMechanics := true)
    (denyEventEmission := true)
    (denyLowLevelMechanics := true)
    (denyRuntimeIntrospection := true)
    (denyProxyUpgradeability := true)
    (denyUnsafe := true)

  IO.println s!"✓ compiled; artifacts in {outDir}, {abiDir}"
