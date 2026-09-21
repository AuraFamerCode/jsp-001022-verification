# JSP-001022 — Independent Lean Verification Report

**Problem:** JSP-001022 (Justin Sun Prize bank) = Erdős Problem **#1217** (ESS66 divisibility
chains), resolved by **Theorem 1.6** of arXiv:2605.00301 (ABLLPSTT26).

**What this repository is:** an *independent verification* of the existing Lean 4
formalization at [`YuanheZ/Prim`](https://github.com/YuanheZ/Prim) (LeanMarathon,
arXiv:2606.05400), performed on **2026-09-21** from a fresh clone with a from-scratch
toolchain install. **This repo contains no Lean proof source and claims no authorship**
of the formalization; it documents the rebuild, axiom audit, and `lean-verify` audit run,
as public evidence for catalog submission.

## Verified artifact

| | |
| --- | --- |
| Repository | https://github.com/YuanheZ/Prim |
| Branch / commit | `main` @ `a303f6bd23bb8f29a833d1d70327528359180995` |
| Proof file | `LeanMarathon/Main.lean` (14,592 lines, 308 declarations) |
| Target theorem | `erdos_sarkozy_szemeredi_1217` (line 14584) |
| Toolchain | `leanprover/lean4:v4.30.0-rc2` (repo-root `lean-toolchain`) |
| Dependencies | Mathlib via repo `lake-manifest.json` at that commit |

## Target statement (verbatim from Main.lean:14584)

```lean
theorem erdos_sarkozy_szemeredi_1217 :
    ∀ A : Set ℕ, 0 < upper_doubly_log_density A ->
      ∃ n : ℕ → ℕ,
        strictly_increasing_divisibility_chain n ∧
        chain_in_set n A ∧
        upper_chain_density_at_least n (upper_doubly_log_density A)
```

This matches the original Theorem 1.6 scope: every set `A ⊆ ℕ` with positive upper doubly
logarithmic density contains an infinite strictly increasing divisibility chain inside `A`
whose own upper doubly log density is at least `Δ(A)` (the "controlled growth" clause).

## Correspondence to the original problem

| Requirement (Erdős #1217 / Thm 1.6) | Lean declaration (Main.lean) |
| --- | --- |
| Δ(A) = limsup_{x→∞} (Σ_{a∈A, a≤x} Λ(a)/a)/log log x > 0 | `upper_doubly_log_density` (:6802), `erdos_sum_up_to` (:6792) |
| infinite chain n₀ ∣ n₁ ∣ n₂ ∣ ⋯, strictly increasing | `strictly_increasing_divisibility_chain` (:6833), index type ℕ |
| every term lies in A | `chain_in_set` (:6841) |
| chain density ≥ Δ(A) | `upper_chain_density_at_least` (:6871) |
| paper §9 architecture (weighted random chain → extraction) | `probabilistic_dense_ambient_chain` (:14423), `dense_hits_subchain_in_set` (:14464) |

## Axiom audit (Step: `#print axioms` on every target)

```
'erdos_sarkozy_szemeredi_1217' depends on axioms: [propext, Classical.choice, Quot.sound]
'probabilistic_dense_ambient_chain' depends on axioms: [propext, Classical.choice, Quot.sound]
'dense_hits_subchain_in_set' depends on axioms: [propext, Classical.choice, Quot.sound]
```

Standard Lean axioms only. Repo-wide sweep at the pinned commit:
**0** `sorry`/`sorryAx`/`admit`, **0** `native_decide`, **0** custom `axiom` declarations.

## lean-verify audit run

`skills/lean-verify/scripts/audit.py` from TheJustinSunPrize/awards, manifest with the
three targets above. Result (see `verification/audit-run-bridges/result.json`):

```
mechanical_status: standard_axioms_only
inputs_stable:     true
preflight issues:  none
after issues:      none
targets: thm-1217, lem-prob-chain, lem-extract — all standard_axioms_only
```

## Reproduction

```bash
curl https://elan.lean-lang.org/elan-init.sh -sSf | sh -s -- -y
export ELAN_HOME="$HOME/.elan"; export PATH="$ELAN_HOME/bin:$PATH"
git clone https://github.com/YuanheZ/Prim && cd Prim
git checkout a303f6bd23bb8f29a833d1d70327528359180995
lake update && lake build            # ~14.6k-line file; builds clean
# axiom audit:
cat > Audit.lean <<'EOF'
import LeanMarathon.Main
#print axioms erdos_sarkozy_szemeredi_1217
#print axioms probabilistic_dense_ambient_chain
#print axioms dense_hits_subchain_in_set
EOF
lake env lean Audit.lean
```

## Limitations / honesty notes

- Proof-structure correspondence was checked against the paper text via public mirrors
  (arxiv.org unreachable from the verification host); the Section 9 tail
  (uniform-integrability / reverse Fatou) was confirmed through secondary mirrors only.
- Statement faithfulness: high confidence. Line-by-line audit of the full proof DAG
  against the paper PDF was not performed.
- Trust anchor: Lean kernel + Mathlib at the pinned versions; verification was performed
  independently of the original repo's own claims.
- The formalization authorship is LeanMarathon's (see arXiv:2606.05400); this repository
  documents verification only.

## Related upstream activity (context, 2026-09)

- TheJustinSunPrize/awards PR #1286 (open): records `plby/lean-proofs` @ 8822f7d
  (`Erdos1217.lean`), proof committed 2026-09-15.
- PRs #1074 (closed) / #2053 (open): record formalizations of Erdős Problem **#1196**
  (primitive-set reciprocal sum) — a different statement from JSP-001022 (#1217).
- PR #1723 (open): self-described as not a complete proof (numerical instances only).
- Priority note: `YuanheZ/Prim` proof commit is dated **2026-06-04**.
