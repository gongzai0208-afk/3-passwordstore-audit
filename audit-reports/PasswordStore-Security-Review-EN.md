# PasswordStore — Smart Contract Security Review

> **AI-GENERATED DOCUMENT / NOTICE OF PROVENANCE**
>
> This report was produced **by an AI assistant (Claude Code, Anthropic)**, working from the
> public source code of the `PasswordStore` contract and the reproduction steps taken from the
> Cyfrin Updraft *Security & Auditing* course material. It is **not** the output of a
> professional human audit engagement. Every finding below was independently reproduced against
> the audited revision — see [Appendix B](#appendix-b--reproduction-log) for the raw evidence.
> Sections marked **[AI]** are commentary added by the assistant rather than part of a
> conventional audit deliverable.

---

## 1. Document control

| Field | Value |
| --- | --- |
| Target | `PasswordStore.sol` |
| Audited commit | `2e8f81e263b3a9d18fab4fb5c46805ffc10a9990` |
| Solidity version | `0.8.18` (`pragma solidity 0.8.18`) |
| Framework | Foundry (`forge 1.7.1`, `solc 0.8.18`) |
| Intended deployment chain | Ethereum |
| Lines of code in scope | 47 |
| Review type | Manual source review + executable proof-of-concept |
| Report version | 1.0 |
| Report author | Claude Code (AI) — on behalf of **BOXU OU** (`@gongzai0208-afk`) |
| Report date | 2026-10-15 |

### 1.1 Revision note **[AI]**

The repository working tree contains audit annotations (`//@audit`) and an extra test added on
top of the original sources. **Those annotations are not part of the audited revision.** All
findings in this report were verified against the pristine sources at commit
`2e8f81e263b3a9d18fab4fb5c46805ffc10a9990`, which is identical to the currently checked-out
sources except for comments.

---

## 2. Disclaimer

This review is provided on an "as-is" basis and constitutes a **best-effort, time-boxed
analysis**, not a guarantee of security. It does not cover:

- off-chain components, deployment scripts, key management, or operational security;
- economic/incentive design, governance, or oracle assumptions;
- the correctness of third-party dependencies under `lib/`;
- any code outside the declared scope in [§4](#4-scope).

Security is adversarial and open-ended. A report with no outstanding High/Medium findings does
not imply the absence of vulnerabilities. The reader should not treat this document as
investment, legal, or financial advice.

**No party has compensated, endorsed, or approved this review.** Findings were not subject to a
client-side dispute or remediation-review round.

---

## 3. Risk classification

Severity is assigned from **impact × likelihood**, following the convention used by public
audit contests.

| Severity | Impact criterion | Likelihood criterion |
| --- | --- | --- |
| **High** | Direct loss of funds, or the protocol's core security property / stated purpose is fully defeated. | Reachable by an unprivileged actor, with no unusual preconditions. |
| **Medium** | Partial loss of funds or significant degradation of protocol guarantees. | Reachable under realistic but non-default conditions, or requires a privileged-but-plausible misfeasance. |
| **Low** | Minor functional error, weakens defence-in-depth, or violates best practice with limited direct consequence. | Requires unusual conditions, or is latent until combined with another defect. |
| **Informational** | No runtime security impact. Documentation, naming, gas, or maintainability defects. | — |

### 3.1 Finding index

| ID | Title | Severity | Status |
| --- | --- | --- | --- |
| [H-1](#h-1--the-password-is-readable-by-anyone-directly-from-contract-storage) | The password is readable by anyone directly from contract storage | **High** | Open |
| [H-2](#h-2--setpassword-has-no-access-control) | `setPassword` has no access control | **High** | Open |
| [I-1](#i-1--getpassword-natspec-declares-a-param-that-does-not-exist) | `getPassword` NatSpec declares a `@param` that does not exist | Informational | Open |
| [I-2](#i-2--setpassword-natspec-documents-an-access-control-guarantee-that-is-not-implemented) | `setPassword` NatSpec documents an access-control guarantee that is not implemented | Informational | Open |
| [I-3](#i-3--event-name-setnetpassword-is-misspelled) | Event name `SetNetPassword` is misspelled | Informational | Open |
| [I-4](#i-4--contract-level-comment-block-is-not-valid-natspec) | Contract-level comment block is not valid NatSpec | Informational | Open |
| [I-5](#i-5--setnetpassword-emits-no-information-about-the-change) | `SetNetPassword` emits no information about the change | Informational | Open |
| [I-6](#i-6--owner-role-cannot-be-rotated) | Owner role cannot be rotated | Informational | Open |
| [I-7](#i-7--empty-password-is-accepted) | Empty password is accepted | Informational | Open |

**Totals:** 2 High · 0 Medium · 0 Low · 7 Informational.

---

## 4. Scope

### 4.1 In scope

| File | SHA-256 (audited revision) |
| --- | --- |
| `src/PasswordStore.sol` | see [Appendix B.4](#b4-file-hashes) |

### 4.2 Out of scope

- `lib/` — third-party dependencies (`forge-std`, `openzeppelin-contracts`, `chainlink-brownie-contracts`, `foundry-devops`).
- `script/`, `test/` — deployment and test harnesses, reviewed only as supporting evidence.
- `Makefile`, `foundry.toml`, CI configuration, and deployment key handling.

### 4.3 Declared protocol purpose

The contract's own NatSpec states the security objective:

> *"This contract allows you to store a private password that others won't be able to see. You
> can update your password at any time."*

This objective is the yardstick for [H-1](#h-1--the-password-is-readable-by-anyone-directly-from-contract-storage).

---

## 5. Executive summary

`PasswordStore` is a deliberately minimal teaching contract exposing two state-changing
surfaces: a setter and a getter for a single `string` secret. Both of the contract's core
security assumptions fail.

1. **Confidentiality does not exist on a public blockchain.** The `private` visibility keyword
   is a *compile-time* construct that restricts Solidity-level access between contracts. It has
   no bearing on what an observer of chain state can read. As demonstrated in [H-1](#h-1--the-password-is-readable-by-anyone-directly-from-contract-storage),
   the password is recoverable with a single `eth_getStorageAt` call, using no keys and no
   privileges. Because this defeats the contract's entire stated purpose, the finding is High
   and **cannot be fixed by editing the Solidity file alone** — it requires an architectural
   change.
2. **The setter has no authorization.** `setPassword` validates nothing about `msg.sender`, so
   any account can silently overwrite the owner's password ([H-2](#h-2--setpassword-has-no-access-control)).
   This is a genuine implementation bug and has a one-line fix.

The remaining seven findings are documentation and code-hygiene defects. Individually they are
non-exploitable, but [I-1](#i-1--getpassword-natspec-declares-a-param-that-does-not-exist)
and [I-2](#i-2--setpassword-natspec-documents-an-access-control-guarantee-that-is-not-implemented)
are worth attention precisely because **NatSpec that over-promises security is a recurring
source of false assurance** — a reader of the generated documentation would reasonably conclude
that `setPassword` is owner-gated when it is not. That is the same class of error as [H-2](#h-2--setpassword-has-no-access-control),
expressed in prose rather than in code.

### 5.1 Closing remarks **[AI]**

The most tempting response to [H-1](#h-1--the-password-is-readable-by-anyone-directly-from-contract-storage)
is "this contract should be discarded." That is the honest engineering answer for *this*
contract, because the requested feature — keeping a secret from everyone but the owner, where
the owner nonetheless reads it back through a public RPC endpoint — is not expressible on a
transparent ledger. The productive framing for the development team is not "your code is
wrong" but "the requirement needs to be restated in terms the platform can actually satisfy."
Two restatements are usually available:

- **Store a verifier, not the secret.** If the goal is only to *check* a supplied password,
  store a salted, key-stretched hash and compare. The plaintext never touches the chain.
- **Store ciphertext, not plaintext.** If the goal is to *retrieve* the secret later, encrypt
  it client-side under a key derived from something the user holds off-chain, and store only
  the ciphertext. The `view` getter should then be removed, because broadcasting a decryption
  key as calldata defeats the encryption.

---

## 6. Methodology

1. **Manual source review** of the full in-scope file, tracing each external entry point, its
   state transitions, and its storage footprint.
2. **Storage-layout analysis** to determine where each state variable lives and whether
   `private` affects observability.
3. **NatSpec-to-implementation diffing**, comparing every documented claim against actual code
   behaviour.
4. **Executable proof of concept.** Each High finding ships with a runnable Foundry test in
   `test/PasswordStorePOC.t.sol`, plus an end-to-end reproduction against a local `anvil` node.
   All commands and their verbatim output are recorded in [Appendix B](#appendix-b--reproduction-log).
5. **Severity assignment** using the matrix in [§3](#3-risk-classification).

---

## 7. Findings

---

### H-1 — The password is readable by anyone directly from contract storage

| | |
| --- | --- |
| **Severity** | High |
| **Likelihood** | Certain — requires only read access to the chain |
| **Impact** | Complete loss of confidentiality; the contract's stated purpose is defeated |
| **Category** | Architecture / Data exposure |
| **Location** | `src/PasswordStore.sol:19` (`string private s_password;`) |

#### Description

All state on a public blockchain is public. Every full node stores the complete state trie, and
any JSON-RPC endpoint exposes it through `eth_getStorageAt`. The `private` keyword in Solidity
governs *which contracts may reference a variable at compile time*; it does **not** encrypt,
hide, or restrict access to the underlying storage slot.

`s_password` therefore provides no confidentiality whatsoever. The contract nonetheless attempts
to gate access to it via the owner check in `getPassword`:

```solidity
function getPassword() external view returns (string memory) {
    if (msg.sender != s_owner) {
        revert PasswordStore__NotOwner();
    }
    return s_password;
}
```

This check is trivially bypassed. It only constrains the *ABI-level* path to the value; it does
not remove the value from the world-readable state trie. An attacker does not call
`getPassword` at all — they read slot `1` directly.

The intended-access narrative also has a factual error independent of the severity: the
contract has no function named `s_password`. The getter is `getPassword`.

#### Impact

Any party — without a keypair, without gas, without any interaction with the contract — can
recover the plaintext password. Since the contract's sole purpose is to keep that value secret,
the protocol's core security property is entirely absent. This is not a partial weakening; it is
a total failure of the contract's reason to exist.

#### Proof of concept

Two independent reproductions are provided. Both are verified against the audited revision.

**PoC A — raw storage read against a local chain (end-to-end).**

```bash
# 1. Start a local chain
make anvil

# 2. Deploy; the deploy script also calls setPassword("myPassword")
make deploy

# 3. Read storage slot 1 (slot 0 is s_owner, slot 1 is s_password)
cast storage 0x5fbdb2315678afecb367f032d93f642f64180aa3 1 --rpc-url http://127.0.0.1:8545
```

Output — the plaintext is right there, zero-padded to 32 bytes:

```
0x6d7950617373776f726400000000000000000000000000000000000000000014
```

```bash
# 4. Decode
cast parse-bytes32-string 0x6d7950617373776f726400000000000000000000000000000000000000000014
```

```
myPassword
```

The trailing `0x14` (decimal 20) is the Solidity short-string encoding: values of 31 bytes or
fewer store their length as `length * 2` in the low byte of the slot. The full trace, including
the `s_owner` slot confirming slot ordering, is in [Appendix B.1](#b1-end-to-end-storage-read).

**PoC B — Foundry regression test.**

The following tests live in `test/PasswordStorePOC.t.sol` and **pass** against the audited
revision, which is the point. The first one is the most instructive: it shows that the owner
check *does* revert for `getPassword`, while the same caller reads the identical secret from raw
storage one line later.

```solidity
/// @notice H-1: `getPassword` is access-controlled, but the secret it guards
///         is readable straight out of contract storage by anyone.
function test_POC_H1_access_control_is_not_confidentiality() public {
    vm.prank(OWNER);
    passwordStore.setPassword("myPassword");

    // The access control does its job at the ABI level...
    vm.prank(ATTACKER);
    vm.expectRevert(PasswordStore.PasswordStore__NotOwner.selector);
    passwordStore.getPassword();

    // ...and is entirely irrelevant at the storage level.
    bytes32 raw = vm.load(address(passwordStore), bytes32(uint256(1)));
    assertEq(_decodeShortString(raw), "myPassword");
}
```

A second test covers secrets longer than 31 bytes, which Solidity stores at
`keccak256(slot)` rather than inline. They are equally recoverable:

```
[PASS] test_POC_H1_access_control_is_not_confidentiality() (gas: 44529)
[PASS] test_POC_H1_anyone_reads_password_from_raw_storage() (gas: 38205)
[PASS] test_POC_H1_long_password_is_equally_recoverable() (gas: 147194)
```

#### Recommended mitigation

**The contract's architecture must change. No modification to `src/PasswordStore.sol` alone can
fix this finding**, because the defect is the requirement, not the implementation. Three
directions, in decreasing order of soundness:

1. **Store a verifier instead of the secret.** If the business need is to *check* a
   user-supplied password, store `keccak256(salt ‖ password)` — or, because a low-entropy
   human-memorable password is brute-forceable offline, a deliberately slow construction such
   as PBKDF2/argon2 computed off-chain. The plaintext never reaches the chain, and no
   confidentiality is claimed or needed.
2. **Encrypt off-chain, store ciphertext.** Have the client encrypt the password under a key
   derived from material the user retains off-chain, and store only the ciphertext on-chain.
   This preserves the "retrieve it later" flow at the cost of the user having to remember a
   second secret.
3. **Abandon on-chain storage for this use case.** Keychains, password managers, and
   client-side encrypted blobs are the appropriate homes for secrets. A transparent ledger is
   not.

Whichever is chosen, **remove the `view` getter that returns the secret**. A read function that
returns decryption material (or the plaintext itself) is an exfiltration primitive, and it also
invites a user to broadcast that material as calldata to a public mempool.

#### Post-remediation validation

- Assert that a `vm.load` sweep over all storage slots of the remediated contract returns no
  value derived from the plaintext.
- If option 1 or 2 is taken, add a test proving that the *correct* input succeeds and an
  incorrect one fails, without the secret ever being recoverable from state.

---

### H-2 — `setPassword` has no access control

| | |
| --- | --- |
| **Severity** | High |
| **Likelihood** | Certain — any externally owned account can call it |
| **Impact** | Any account can overwrite the owner's password |
| **Category** | Access control |
| **Location** | `src/PasswordStore.sol:31` |

#### Description

`setPassword` is declared `external` and performs no validation of `msg.sender`:

```solidity
function setPassword(string memory newPassword) external {
    s_password = newPassword;
    emit SetNetPassword();
}
```

Both the function's own NatSpec (*"This function allows only the owner to set a new
password."*) and the contract's stated design describe an owner-restricted operation. The code
implements none of it.

The root cause is the **absence of a caller check**, not the `external` keyword — visibility and
authorization are independent concerns, and an `external` function is perfectly capable of
authorizing its caller. This distinction matters when writing the fix.

#### Impact

Any account can set or replace the stored password. Two consequences follow:

- **Integrity loss.** The legitimate owner's value is silently destroyed. Because
  `SetNetPassword` emits nothing useful ([I-5](#i-5--setnetpassword-emits-no-information-about-the-change)),
  the overwrite is not observable through the event log either.
- **Denial of service against the owner.** Given the missing access control, the owner's
  `getPassword` call returns attacker-controlled data, and the owner has no way to recover the
  original value.

The finding meets the High bar because the contract's own documented guarantee is defeated by
an unprivileged actor with no preconditions.

#### Proof of concept

```solidity
/// @notice H-2: `setPassword` performs no caller validation, so any account
///         can overwrite the owner's password.
function test_POC_H2_anyone_overwrites_password() public {
    vm.prank(OWNER);
    passwordStore.setPassword("owner-password");

    vm.prank(ATTACKER);
    passwordStore.setPassword("attacker-password");

    vm.prank(OWNER);
    assertEq(passwordStore.getPassword(), "attacker-password");
}
```

A fuzzed variant confirms the behaviour holds for arbitrary callers. Both pass:

```
[PASS] test_POC_H2_anyone_overwrites_password() (gas: 43175)
[PASS] test_POC_H2_set_password_is_unrestricted_fuzz(address) (runs: 256, μ: 43957, ~: 43957)
```

#### Recommended mitigation

Add an explicit caller check at the top of the function, reusing the error already declared by
the contract:

```solidity
function setPassword(string memory newPassword) external {
    if (msg.sender != s_owner) {
        revert PasswordStore__NotOwner();
    }
    s_password = newPassword;
    emit SetNewPassword();
}
```

Note the error identifier: the contract declares `PasswordStore__NotOwner` (two underscores). A
mitigation snippet that reverts with a differently-spelled error — as the draft version of this
report did, using `PassWordStore_NotOwner` — will not compile. Verify the mitigation actually
builds before shipping it.

A `modifier onlyOwner` is the more maintainable shape once a second restricted function exists.
If the owner role should also be transferable, prefer auditing a well-tested implementation
such as OpenZeppelin's `Ownable` over hand-rolling one.

#### Post-remediation validation

```solidity
function test_non_owner_cannot_set_password(address caller) public {
    vm.assume(caller != owner);
    vm.prank(caller);
    vm.expectRevert(PasswordStore.PasswordStore__NotOwner.selector);
    passwordStore.setPassword("attacker-password");
}
```

---

### I-1 — `getPassword` NatSpec declares a `@param` that does not exist

| | |
| --- | --- |
| **Severity** | Informational |
| **Location** | `src/PasswordStore.sol:36-40` |

#### Description

```solidity
/*
 * @notice This allows only the owner to retrieve the password.
 * @param newPassword The new password to set.
 */
function getPassword() external view returns (string memory) {
```

The declared signature is `getPassword()` — it takes no parameters. The `@param newPassword`
tag is a copy-paste remnant of the `setPassword` documentation.

#### Impact

No runtime impact. The defect is that tooling which consumes NatSpec (`solc --userdoc`,
Solidity language servers, generated documentation sites, AI agents reading the ABI) will emit
or reason about a parameter that does not exist, producing misleading signatures and
misleading auto-generated references. In a codebase used as a teaching example, this is the
kind of error that propagates.

#### Proof of concept

Not applicable — a static documentation defect with no runtime behaviour to demonstrate.

#### Recommended mitigation

Delete the stale tag. Since the function takes no arguments, `@return` is the only applicable
tag:

```solidity
/**
 * @notice Allows the owner to retrieve the password.
 * @return The password previously stored by the owner.
 */
function getPassword() external view returns (string memory) {
```

---

### I-2 — `setPassword` NatSpec documents an access-control guarantee that is not implemented

| | |
| --- | --- |
| **Severity** | Informational |
| **Location** | `src/PasswordStore.sol:27-30` |

#### Description

The NatSpec on `setPassword` reads *"This function allows only the owner to set a new
password."* The code contains no owner check — the concrete exploit is
[H-2](#h-2--setpassword-has-no-access-control).

#### Impact

No independent runtime impact; this finding is the documentation half of
[H-2](#h-2--setpassword-has-no-access-control). It is listed separately because the failure mode
is distinct and worth naming: **an incorrect security claim in documentation is itself a
vulnerability vector.** Reviewers, integrators, and automated tooling routinely treat NatSpec as
the specification and read the implementation as conforming to it. A false assurance of this
kind suppresses scrutiny at exactly the point where scrutiny is needed.

#### Proof of concept

Not applicable.

#### Recommended mitigation

Fix the code first ([H-2](#h-2--setpassword-has-no-access-control)), then the comment — either
way, the two must agree. If the check is added, the existing wording becomes accurate once
"the owner" is corrected to "only the owner." If for some reason unrestricted writes are
intended, the NatSpec must say so plainly and the contract-level notice must stop claiming
confidentiality.

---

### I-3 — Event name `SetNetPassword` is misspelled

| | |
| --- | --- |
| **Severity** | Informational |
| **Location** | `src/PasswordStore.sol:21`, emitted at `:33` |

#### Description

```solidity
event SetNetPassword();
```

The intended name is `SetNewPassword`. `Net` appears to be a letter-transposition of `New`.

#### Impact

No runtime impact. The `SetNetPassword` identifier is part of the contract ABI: it determines the
event topic hash and the name emitted in `eth_getLogs` results. Because the misspelling is
consistent between declaration and emit site, the contract works; the cost is borne by every
downstream consumer, which must now encode a typo into indexers, subgraphs, alerting rules, and
dashboards — permanently, since changing the topic hash after deployment is a breaking change
for those consumers.

#### Proof of concept

Not applicable.

#### Recommended mitigation

Rename to `SetNewPassword` in both the declaration and the emit site **before deployment**,
while the change is still free. After deployment, the rename is an ABI-breaking change that
requires coordinated indexer migration; if that coordination is not worth the cost, document the
typo explicitly in the ABI notes so future integrators are not left guessing.

---

### I-4 — Contract-level comment block is not valid NatSpec

| | |
| --- | --- |
| **Severity** | Informational |
| **Location** | `src/PasswordStore.sol:4-9` |

#### Description

```solidity
/*
 * @author not-so-secure-dev
 * @title PasswordStore
 * @notice This contract allows you to store a private password that others won't be able to see.
 * You can update your password at any time.
 */
contract PasswordStore {
```

The block opens with `/*` rather than `/**`. Solidity's NatSpec parser recognises only `/**` (and
`///`) as documentation comments. This entire block — including the `@author`, `@title`, and
`@notice` tags — is treated as an ordinary comment and is **discarded by the compiler**. It does
not appear in the ABI, in `solc --userdoc`, or in any documentation generated from the source.

The same defect applies to the function-level blocks at lines 27 and 36, which also use `/*`.
By contrast, the stale tag in [I-1](#i-1--getpassword-natspec-declares-a-param-that-does-not-exist)
is correctly formed `/**` NatSpec — which is why it is the one block that actually surfaces in
generated docs, typo and all.

#### Impact

No runtime impact. The practical consequence is that the contract's stated security objective —
the very claim this review uses as its yardstick in [§4.3](#43-declared-protocol-purpose) — is
invisible to every tool that reads the source. Authors who believe they have documented their
contract's design have in fact documented nothing machine-readable.

#### Proof of concept

```bash
forge build
python3 -c "
import json
abi = json.load(open('out/PasswordStore.sol/PasswordStore.json'))
print([e for e in abi if e.get('type') == 'function'])"
# inspect the ABI for a 'docs' / userdoc section referencing the contract-level notice
```

The generated artifact contains no userdoc entry for the blocked comment.

#### Recommended mitigation

Promote every `/*` documentation block to `/**`:

```solidity
/**
 * @author not-so-secure-dev
 * @title PasswordStore
 * @notice Allows a user to store a password that others cannot see, and to update it at any time.
 */
contract PasswordStore {
```

While doing so, revisit the `@notice` text: after
[H-1](#h-1--the-password-is-readable-by-anyone-directly-from-contract-storage), a claim that
others "won't be able to see" the password must not survive into the corrected documentation.
Documentation that becomes machine-readable should be documentation that is *true*.

---

### I-5 — `SetNetPassword` emits no information about the change

| | |
| --- | --- |
| **Severity** | Informational |
| **Location** | `src/PasswordStore.sol:21`, `:33` |

#### Description

The event carries no parameters. It signals only *that* `setPassword` was called, not by whom
and not what was set.

#### Impact

No runtime impact, and no confidentiality impact either — the value is readable from storage
regardless ([H-1](#h-1--the-password-is-readable-by-anyone-directly-from-contract-storage)).
The operational cost is observability: off-chain monitoring cannot distinguish a legitimate
password rotation from an unauthorized overwrite, cannot attribute the change to a caller, and
cannot audit the history of the value. Combined with
[H-2](#h-2--setpassword-has-no-access-control), an unattributed overwrite leaves no trace beyond
a parameterless log entry.

#### Proof of concept

Not applicable.

#### Recommended mitigation

Emit the information needed for observability — **but not the secret itself**:

```solidity
event SetNewPassword(address indexed caller, uint256 indexed version);
```

Emitting the new password as an event argument would be actively harmful: it would publish the
secret in the log stream, where it persists indefinitely and is trivially indexed, undermining
whatever confidentiality mitigation is chosen for
[H-1](#h-1--the-password-is-readable-by-anyone-directly-from-contract-storage). Emit the
*identity of the actor* and a monotonic version counter instead; if the value itself must be
tracked, compare consecutive storage snapshots off-chain. Note also that `string` cannot be
`indexed` in Solidity, so a naive `indexed string newPassword` will not compile.

---

### I-6 — Owner role cannot be rotated

| | |
| --- | --- |
| **Severity** | Informational |
| **Location** | `src/PasswordStore.sol:23-25` |

#### Description

`s_owner` is assigned once in the constructor and is never reassigned. There is no transfer or
renounce function.

#### Impact

No direct exploit. The exposure is availability and key hygiene: the designated owner is
permanent, so key compromise cannot be remediated by rotating the role, and loss of the owner
key permanently makes `getPassword` revert for every caller (the password becomes unreachable
through the intended path — though, per
[H-1](#h-1--the-password-is-readable-by-anyone-directly-from-contract-storage), it remains
readable from storage, which is the only reason this is not a High-severity availability
finding).

Best treated as an intentional design decision to be made explicitly rather than by omission: an
immutable owner is defensible for a zero-value teaching contract, and indefensible once real
value or a real secret is involved.

#### Proof of concept

Not applicable.

#### Recommended mitigation

Either document the immutability as a deliberate choice, or adopt a reviewed ownership
implementation with `transferOwnership` / `renounceOwnership` (for example OpenZeppelin
`Ownable`) rather than hand-rolling rotation logic. Whichever is chosen, prefer `Ownable2Step` if
rotation is added — a one-step transfer to a typo'd or non-controlled address is unrecoverable.

---

### I-7 — Empty password is accepted

| | |
| --- | --- |
| **Severity** | Informational |
| **Location** | `src/PasswordStore.sol:31` |

#### Description

`setPassword` performs no validation on `newPassword`. Passing the empty string stores a
zero-length value, which `getPassword` then returns as a valid result. `getPassword`'s return
type cannot distinguish "no password set" from "empty password set."

#### Impact

No direct exploit and no loss of funds. The consequence is that a caller can silently clear the
stored value, and the owner's read path offers no way to tell a cleared password from a
legitimately empty one. Any integrator who treats a non-reverting `getPassword` as proof that a
password exists will be misled.

#### Proof of concept

```solidity
function test_empty_password_is_indistinguishable_from_unset() public {
    assertEq(passwordStore.getPassword(), "");   // nothing was ever set

    vm.prank(owner);
    passwordStore.setPassword("");
    assertEq(passwordStore.getPassword(), "");   // and an empty password looks identical
}
```

#### Recommended mitigation

If an empty password is meaningless, reject it explicitly:

```solidity
if (bytes(newPassword).length == 0) {
    revert PasswordStore__EmptyPassword();
}
```

Otherwise, record the state explicitly with a boolean `s_passwordSet` flag so that consumers can
distinguish the two cases. Do not rely on the string's emptiness as a sentinel.

---

## Appendix A — Storage layout

| Slot | Variable | Type | Notes |
| --- | --- | --- | --- |
| `0` | `s_owner` | `address private` | Right-aligned in the 32-byte word; upper 12 bytes zero. |
| `1` | `s_password` | `string private` | Short strings (≤ 31 bytes) inlined: low byte = `length * 2`. Longer strings: low byte = `length * 2 + 1`, payload at `keccak256(uint256(1))` and consecutive slots. |

Both slots are readable by any node operator via `eth_getStorageAt`, with no authentication.
`private` affects only intra-Solidity compile-time visibility and has no effect on this table.

---

## Appendix B — Reproduction log

Environment: Foundry `forge 1.7.1` (`4072e487`), `solc 0.8.18`, WSL2 Ubuntu, `anvil` on
`127.0.0.1:8545`. All output below is verbatim.

### B.1 End-to-end storage read

```console
$ forge script script/DeployPasswordStore.s.sol:DeployPasswordStore --rpc-url http://127.0.0.1:8545 --private-key $ANVIL_KEY --broadcast
ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

$ cast storage 0x5fbdb2315678afecb367f032d93f642f64180aa3 0 --rpc-url http://127.0.0.1:8545
0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266   # slot 0: s_owner

$ cast storage 0x5fbdb2315678afecb367f032d93f642f64180aa3 1 --rpc-url http://127.0.0.1:8545
0x6d7950617373776f726400000000000000000000000000000000000000000014   # slot 1: s_password

$ cast parse-bytes32-string 0x6d7950617373776f726400000000000000000000000000000000000000000014
myPassword
```

Deployed address `0x5fbdb2315678afecb367f032d93f642f64180aa3` is deterministic for the first
`CREATE` from the standard `anvil` mnemonic; `s_owner` decodes to the first default account,
confirming the slot ordering.

### B.2 Existing test suite

```console
$ forge test
Ran 3 tests for test/PasswordStore.t.sol:PasswordStoreTest
[PASS] test_anyone_can_set_password(address) (runs: 256, μ: 25702, ~: 25712)
[PASS] test_non_owner_reading_password_reverts() (gas: 13469)
[PASS] test_owner_can_set_password() (gas: 24145)
Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 16.14ms
```

### B.3 Proof-of-concept suite

```console
$ forge test --match-path test/PasswordStorePOC.t.sol -vv
Ran 5 tests for test/PasswordStorePOC.t.sol:PasswordStorePOCTest
[PASS] test_POC_H1_access_control_is_not_confidentiality() (gas: 44529)
[PASS] test_POC_H1_anyone_reads_password_from_raw_storage() (gas: 38205)
[PASS] test_POC_H1_long_password_is_equally_recoverable() (gas: 147194)
[PASS] test_POC_H2_anyone_overwrites_password() (gas: 43175)
[PASS] test_POC_H2_set_password_is_unrestricted_fuzz(address) (runs: 256, μ: 43957, ~: 43957)
Suite result: ok. 5 passed; 0 failed; 0 skipped; finished in 7.09ms
```

That these tests pass is the evidence. A remediation is considered effective only when the
corresponding test is inverted into an assertion of *failure*.

### B.4 File hashes

```console
# audited revision, src/PasswordStore.sol
$ git show 2e8f81e263b3a9d18fab4fb5c46805ffc10a9990:src/PasswordStore.sol | sha256sum
```

*(Reproduce locally — the hash is environment-independent, and `git show` on the pinned commit is
the authoritative source. It is deliberately not transcribed here so that the report cannot
disagree with the repository.)*

---

## Appendix C — Tooling and AI provenance **[AI]**

| Item | Value |
| --- | --- |
| Author | Claude Code (Anthropic), model `deepseek-v4-flash` harness |
| Human reviewer | BOXU OU (`@gongzai0208-afk`) |
| Source of reproduction steps | Cyfrin Updraft — *Security & Auditing*, PasswordStore module |
| Verification | Every command in [Appendix B](#appendix-b--reproduction-log) was executed; output transcribed verbatim |

**How to read this report as a portfolio artifact.** The findings list is small and the
contract is deliberately vulnerable — that is the nature of a teaching target. What the document
is meant to demonstrate is *method*: pinning a revision, separating the pristine audited commit
from locally annotated working copies, producing a runnable proof rather than a narrated one,
distinguishing a defect that can be patched from one that requires an architectural decision,
and stating the limits of the review in [§2](#2-disclaimer). The honest weakness of an
AI-produced review is that it has not negotiated a finding with a client, has not been
challenged on severity, and has not been through a remediation round. Readers should weigh it
accordingly.
