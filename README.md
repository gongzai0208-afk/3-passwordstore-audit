<br/>
<p align="center">
<img src="./password-store-logo.png" width="400" alt="password-store">
</p>
<br/>

# PasswordStore — Smart Contract Security Review

<p>
  <img alt="Solidity" src="https://img.shields.io/badge/Solidity-0.8.18-363636?logo=solidity">
  <img alt="Foundry" src="https://img.shields.io/badge/Built%20with-Foundry-ffb13b">
  <img alt="Findings" src="https://img.shields.io/badge/findings-2%20High%20%2F%207%20Info-red">
  <img alt="AI" src="https://img.shields.io/badge/report-AI--generated-blueviolet">
</p>

A security review of `PasswordStore`, a deliberately vulnerable 47-line teaching contract from the
[Cyfrin Updraft](https://updraft.cyfrin.io/) *Security & Auditing* course.

**This repository is a portfolio piece.** Its purpose is to demonstrate audit *method* — pinning a
revision, proving findings with runnable code rather than narration, and separating a defect that can
be patched from one that requires an architectural decision. It does not claim discovery of novel
vulnerabilities: the target is purpose-built and its flaws are intentional.

---

## Reports

| Document | Language | Notes |
| --- | --- | --- |
| [**PasswordStore-Security-Review-EN.md**](audit-reports/PasswordStore-Security-Review-EN.md) | English | Full report — scope, methodology, findings, reproduction log |
| [**PasswordStore-安全审计报告-CN.md**](audit-reports/PasswordStore-安全审计报告-CN.md) | 中文 | 同等完整的独立报告（非逐句翻译） |
| [**Improvement-Plan.md**](audit-reports/Improvement-Plan.md) | 中文 | 对自有手写草稿的逐条复盘与改进项 |
| [`audit-date/finding_layout.md`](audit-date/finding_layout.md) | mixed | The original hand-written draft, kept unmodified as a record of process |

> **Both reports are AI-generated** (Claude Code, Anthropic) and state so on their first page. Every
> command in them was executed and its output transcribed verbatim.
> [Appendix C](audit-reports/PasswordStore-Security-Review-EN.md#appendix-c--tooling-and-ai-provenance-ai)
> states plainly what that provenance does and does not buy the reader.

---

## Findings at a glance

| ID | Finding | Severity |
| --- | --- | --- |
| **H-1** | The password is readable by anyone directly from contract storage | **High** |
| **H-2** | `setPassword` has no access control | **High** |
| I-1 | `getPassword` NatSpec declares a `@param` that does not exist | Informational |
| I-2 | `setPassword` NatSpec documents an access-control guarantee that is not implemented | Informational |
| I-3 | Event name `SetNetPassword` is misspelled | Informational |
| I-4 | Contract-level comment block is not valid NatSpec (`/*` instead of `/**`) | Informational |
| I-5 | `SetNetPassword` emits no information about the change | Informational |
| I-6 | Owner role cannot be rotated | Informational |
| I-7 | Empty password is accepted | Informational |

**2 High · 0 Medium · 0 Low · 7 Informational**

The two High findings differ in kind, and that distinction is the point of the review:

- **H-2 is a bug.** One missing `if (msg.sender != s_owner)` — a one-line fix.
- **H-1 is a requirement.** `private` is a compile-time construct; it does nothing to hide a value from
  a world-readable state trie. No edit to the Solidity file fixes it. The architecture — or the stated
  goal — has to change. See [§5.1 of the report](audit-reports/PasswordStore-Security-Review-EN.md#51-closing-remarks-ai).

---

## Reproduce

Requires [Foundry](https://getfoundry.sh/).

```bash
git clone --recurse-submodules <this-repo>
cd 3-passwordstore-audit
forge build
```

### Run the tests

```bash
forge test                                          # original suite (3 tests)
forge test --match-path test/PasswordStorePOC.t.sol # proof of concept (5 tests)
```

All 5 PoC tests **pass** — that is the evidence. The assertion in
`test_POC_H1_access_control_is_not_confidentiality` is the most direct illustration of H-1: the same
caller is correctly reverted by `getPassword`, then reads the identical secret out of raw storage on
the next line.

### Read the password off-chain

```bash
# terminal 1
make anvil

# terminal 2
make deploy

# slot 0 = s_owner, slot 1 = s_password
cast storage 0x5fbdb2315678afecb367f032d93f642f64180aa3 1 --rpc-url http://127.0.0.1:8545
# 0x6d7950617373776f726400000000000000000000000000000000000000000014

cast parse-bytes32-string 0x6d7950617373776f726400000000000000000000000000000000000000000014
# myPassword
```

No keys, no privileges, no interaction with the contract. The trailing `0x14` is Solidity's short-string
encoding: `length * 2` in the low byte.

---

## Repository layout

```
src/PasswordStore.sol         Target contract (audited revision: 2e8f81e)
src/notes.md                  Hand-written notes on the contract's intended behaviour
test/PasswordStore.t.sol      Original test suite
test/PasswordStorePOC.t.sol   Proof-of-concept suite referenced by the reports
script/                       Deployment script
audit-reports/                The three AI-generated documents
audit-date/                   Original hand-written draft — left untouched
```

**Audited revision:** `2e8f81e263b3a9d18fab4fb5c46805ffc10a9990`. The working tree carries audit
annotations (`//@audit`) and an extra test on top of it; those annotations are **not** part of the
audited revision. See [§1.1 of the report](audit-reports/PasswordStore-Security-Review-EN.md#11-revision-note-ai).

---

## Scope and limitations

In scope: `src/PasswordStore.sol` only. Out of scope: `lib/` dependencies, `script/`, `test/`, CI
configuration, and deployment key handling.

This is a best-effort, time-boxed review of a teaching contract. It is not a professional audit
engagement, no client commissioned it, and no finding has been through a dispute or remediation-review
round. A review with no outstanding High/Medium findings would not imply the absence of vulnerabilities.

---

## Credits

- Target contract and course material: [Cyfrin Updraft](https://updraft.cyfrin.io/) — *Security & Auditing*
- Original repository: [Cyfrin/3-passwordstore-audit](https://github.com/Cyfrin/3-passwordstore-audit)
- Review and reports: BOXU OU ([@gongzai0208-afk](https://github.com/gongzai0208-afk)), with Claude Code (AI)

<br/>

<details>
<summary><b>Appendix — original project README (restored)</b></summary>

The repository's `README.md` was accidentally overwritten by `forge init` (the Foundry scaffold
template) during the audit. The original content is preserved below, recovered from
`git show HEAD:README.md`. It is worth keeping because it records the audit scope — including the
commit hash that the report pins.

---

# PasswordStore

A smart contract applicatoin for storing a password. Users should be able to store a password and then retrieve it later. Others should not be able to access the password.

- [PasswordStore](#passwordstore)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
    - [Optional Gitpod](#optional-gitpod)
- [Usage](#usage)
  - [Deploy (local)](#deploy-local)
  - [Testing](#testing)
    - [Test Coverage](#test-coverage)
- [Audit Scope Details](#audit-scope-details)
  - [Create the audit report](#create-the-audit-report)

# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

## Quickstart

```
git clone https://github.com/Cyfrin/3-passwordstore-audit
cd 3-passwordstore-audit
forge build
```

### Optional Gitpod

If you can't or don't want to run and install locally, you can work with this repo in Gitpod. If you do this, you can skip the `clone this repo` part.

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#github.com/Cyfrin/3-passwordstore-audit)

# Usage

## Deploy (local)

1. Start a local node

```
make anvil
```

2. Deploy

This will default to your local node. You need to have it running in another terminal in order for it to deploy.

```
make deploy
```

## Testing

```
forge test
```

### Test Coverage

```
forge coverage
```

and for coverage based testing:

```
forge coverage --report debug
```

# Audit Scope Details

- Commit Hash:  2e8f81e263b3a9d18fab4fb5c46805ffc10a9990
- In Scope:
```
./src/
└── PasswordStore.sol
```
- Solc Version: 0.8.18
- Chain(s) to deploy contract to: Ethereum

## Create the audit report

View the [audit-report-templating](https://github.com/Cyfrin/audit-report-templating) repo to install all dependencies.

```bash
cd audits
pandoc 2023-09-01-password-store-report.md -o report.pdf --from markdown --template=eisvogel --listings
```

</details>
