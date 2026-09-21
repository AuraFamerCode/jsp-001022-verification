#!/usr/bin/env bash
# Reproduce the JSP-001022 (Erdos Problem #1217) Lean verification from scratch.
#
# What this does, in order:
#   1. installs a private elan toolchain (does NOT touch your ~/.elan)
#   2. clones https://github.com/YuanheZ/Prim and checks out the pinned commit
#   3. verifies the pinned commit hash and the proof file's SHA-256
#   4. runs `lake update && lake build` (the long step; 10-30 min cold)
#   5. runs `#print axioms` on the three target declarations
#   6. greps for sorry/admit/native_decide/custom axioms
#   7. runs the awards repo's skills/lean-verify/scripts/audit.py
#
# Usage:  bash reproduce.sh [WORKDIR]     (default WORKDIR: ./jsp1022-repro)
# Expected final line:  REPRODUCTION VERIFIED
set -euo pipefail

COMMIT="a303f6bd23bb8f29a833d1d70327528359180995"
TOOLCHAIN="leanprover/lean4:v4.30.0-rc2"
MAIN_SHA256="8ca5eaef73ffacc9b6e350304a4b4c7e4ee9ec3dd3205af339df63d671ed7085"
AWARDS="https://github.com/TheJustinSunPrize/awards"
WORKDIR="${1:-./jsp1022-repro}"

mkdir -p "$WORKDIR" && cd "$WORKDIR"
echo "== [1/7] toolchain =="
export ELAN_HOME="$PWD/elan"
if [ ! -x "$ELAN_HOME/bin/elan" ]; then
  curl https://elan.lean-lang.org/elan-init.sh -sSf | sh -s -- -y --default-toolchain "$TOOLCHAIN"
fi
export PATH="$ELAN_HOME/bin:$PATH"
elan toolchain install "$TOOLCHAIN" >/dev/null 2>&1 || true
echo "toolchain: $TOOLCHAIN"

echo "== [2/7] clone =="
if [ ! -d Prim ]; then git clone -q https://github.com/YuanheZ/Prim.git; fi
cd Prim
git checkout -q "$COMMIT"
GOT="$(git rev-parse HEAD)"
[ "$GOT" = "$COMMIT" ] || { echo "FAIL: checked out $GOT != $COMMIT"; exit 1; }
echo "commit ok: $GOT"

echo "== [3/7] hash check =="
GOT_SHA="$(shasum -a 256 LeanMarathon/Main.lean | cut -d' ' -f1)"
[ "$GOT_SHA" = "$MAIN_SHA256" ] || { echo "FAIL: Main.lean sha256 $GOT_SHA != $MAIN_SHA256"; exit 1; }
echo "sha256 ok: $MAIN_SHA256"

echo "== [4/7] build (long) =="
# NOTE: this repo's lakefile has defaultTargets = ["Prim"] with no such target, and the
# LeanMarathon lib has no root-module file, so plain `lake build` fails. The correct
# invocation is the module-scoped build (the same one audit.py runs from the manifest):
lake update
lake exe cache get >/dev/null 2>&1 || true   # Mathlib build cache; harmless if unused
lake build +LeanMarathon.Main
git checkout -- lake-manifest.json 2>/dev/null || true   # keep the pinned tree clean for step 7

echo "== [5/7] axiom audit =="
cat > ../AuditJsp1022.lean <<'EOF'
import LeanMarathon.Main
#print axioms erdos_sarkozy_szemeredi_1217
#print axioms probabilistic_dense_ambient_chain
#print axioms dense_hits_subchain_in_set
EOF
lake env lean ../AuditJsp1022.lean | tee ../axioms.out
for T in erdos_sarkozy_szemeredi_1217 probabilistic_dense_ambient_chain dense_hits_subchain_in_set; do
  grep -q "'$T' depends on axioms: \[propext, Classical.choice, Quot.sound\]" ../axioms.out \
    || { echo "FAIL: unexpected axioms for $T"; exit 1; }
done

echo "== [6/7] placeholder sweep =="
[ -z "$(grep -n 'sorry\|admit' LeanMarathon/Main.lean | grep -v 'no_sorry' || true)" ] || { echo "FAIL: sorry/admit found"; exit 1; }
[ "$(grep -c 'native_decide' LeanMarathon/Main.lean)" = "0" ] || { echo "FAIL: native_decide found"; exit 1; }
[ -z "$(grep -n '^axiom ' LeanMarathon/Main.lean || true)" ] || { echo "FAIL: custom axiom found"; exit 1; }
echo "sweep clean"

echo "== [7/7] lean-verify audit.py =="
cd ..
if [ ! -d awards ]; then git clone -q --depth 1 "$AWARDS" awards; fi
cat > manifest.json <<EOF
{
  "schema_version": 1,
  "project": { "root": "$PWD/Prim", "commit": "$COMMIT",
               "repository": "https://github.com/YuanheZ/Prim", "toolchain": "$TOOLCHAIN" },
  "problems": [ { "id": "JSP-001022",
    "source": "problems/catalog-1001-1022.md#JSP-001022 (Erdos Problem #1217; Theorem 1.6 of arXiv:2605.00301)",
    "requirements": [ { "id": "req-1",
      "description": "Every set of positive integers with positive upper doubly logarithmic density contains an infinite strictly increasing divisibility chain within the set whose upper chain density is at least Delta(A) (Theorem 1.6 of arXiv:2605.00301).",
      "targets": ["thm-1217"], "coverage": "full",
      "evidence": "erdos_sarkozy_szemeredi_1217 matches the original statement scope; see verification report correspondence table." } ] } ],
  "targets": [ { "id": "thm-1217", "problem": "JSP-001022", "role": "theorem",
    "module": "LeanMarathon.Main", "declaration": "erdos_sarkozy_szemeredi_1217",
    "source": "LeanMarathon/Main.lean" } ]
}
EOF
LAKE="$(command -v lake)"
python3 awards/skills/lean-verify/scripts/audit.py run manifest.json --out audit-run --lake "$LAKE" --timeout 600
python3 - <<'PY'
import json
d = json.load(open("audit-run/result.json"))
assert d["mechanical_status"] == "standard_axioms_only", d["mechanical_status"]
assert d["inputs_stable"] is True
assert not d["preflight"]["issues"] and not d["after"]["issues"]
print("audit.py:", d["mechanical_status"], "| inputs_stable:", d["inputs_stable"])
PY

echo ""
echo "REPRODUCTION VERIFIED"
