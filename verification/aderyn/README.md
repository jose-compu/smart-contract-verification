# Aderyn on SimpleBank

Static scan of [`src/SimpleBank.sol`](../../src/SimpleBank.sol) with **Aderyn 0.6.8**.

Class: static analysis. Tool: [Cyfrin/aderyn](https://github.com/Cyfrin/aderyn). This is not a proof of the five survey properties.

## Result

Aderyn 0.6.8, 88 detectors, Foundry scope `src/` (12 nSLOC):

| Severity | Count | What it is |
| --- | --- | --- |
| High | 1 | `withdraw` sends ETH with `transfer` and does not check the recipient beyond `msg.sender` ("ETH transferred without address checks") |
| Low | 5 | Empty `require` message, `PUSH0`, state change without an event, an ERC-20 heuristic on the same call, unspecific `pragma` |

The high finding is the stipend path in survey property 5, named as a pattern. Aderyn does not show that a reverting receiver restores credits, and it does not address deposit accounting or solvency.

## Run

Aderyn 0.6.8 on `PATH`.

```shell
verification/aderyn/run.sh
```

The script fails if the high count is not 1 or if that transfer finding is absent.

## Trust

- Detectors are heuristics. The ERC-20 low finding is a false classification of `transfer` on a native-ETH vault.
- CI pins Aderyn 0.6.8. A newer detector set can change the low count; the script locks the high finding, not each low title.
