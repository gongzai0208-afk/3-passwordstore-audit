# PasswordStore 智能合约安全审计报告

> **本文档由 AI 生成 · 来源声明**
>
> 本报告由 **AI 助手（Claude Code，Anthropic）** 撰写，输入为 `PasswordStore` 合约的公开源码，以及
> Cyfrin Updraft《Security & Auditing》课程中 PasswordStore 模块的复现步骤。本报告**不是**专业人工审计团队
> 的委托交付物。下文每一条发现均在受审版本上独立复现，原始证据见[附录 B](#附录-b--复现日志)。
> 标注 **[AI]** 的段落为助手补充的评述，不属于传统审计交付物的固定组成部分。

---

## 1. 文档信息

| 项目 | 内容 |
| --- | --- |
| 审计对象 | `PasswordStore.sol` |
| 受审提交 | `2e8f81e263b3a9d18fab4fb5c46805ffc10a9990` |
| Solidity 版本 | `0.8.18`（`pragma solidity 0.8.18`） |
| 审计框架 | Foundry（`forge 1.7.1`、`solc 0.8.18`） |
| 预期部署链 | Ethereum |
| 范围内代码行数 | 47 行 |
| 审计方式 | 人工源码走查 + 可执行概念验证 |
| 报告版本 | 1.0 |
| 报告撰写 | Claude Code（AI），为 **BOXU OU**（`@gongzai0208-afk`）撰写 |
| 报告日期 | 2026-10-15 |

### 1.1 版本说明 **[AI]**

当前工作区在原始源码之上追加了审计批注（`//@audit`）与一个额外测试。**这些批注不属于受审版本。**
本报告全部结论均以提交 `2e8f81e263b3a9d18fab4fb5c46805ffc10a9990` 的原始源码为准，该版本与当前
检出的源码除注释外完全一致。

---

## 2. 免责声明

本报告按“现状”提供，属于**尽力而为、时间受限的分析**，不构成安全保证。以下内容不在本次审计范围内：

- 链下组件、部署脚本、私钥管理与运维安全；
- 经济激励模型、治理机制与预言机假设；
- `lib/` 下第三方依赖的正确性；
- 任何超出[第 4 章](#4-审计范围)声明范围的代码。

安全对抗是开放式的。一份没有高危/中危遗留项的报告，不等于不存在漏洞。读者不应将本文档视为投资、
法律或财务建议。

**本报告未接受任何一方的付费、背书或审核**，发现的严重等级亦未经项目方申辩或复评环节的检验。

---

## 3. 风险等级标准

严重等级由**影响 × 可能性**共同决定，采用公开审计竞赛的通行口径。

| 等级 | 影响判定 | 可能性判定 |
| --- | --- | --- |
| **High（高危）** | 直接造成资金损失，或协议的核心安全属性 / 既定目标被完全击穿。 | 无特权攻击者即可触发，且无异常前置条件。 |
| **Medium（中危）** | 部分资金损失，或协议保证被显著削弱。 | 在现实但非默认条件下可触发，或需要特权角色的不当操作。 |
| **Low（低危）** | 轻微功能错误、纵深防御被削弱，或在直接后果有限的情况下违反最佳实践。 | 需要异常条件，或单独存在时潜伏、需与其他缺陷组合才能触发。 |
| **Informational（提示级）** | 无运行时安全影响。文档、命名、Gas 或可维护性缺陷。 | — |

### 3.1 发现索引

| 编号 | 标题 | 等级 | 状态 |
| --- | --- | --- | --- |
| [H-1](#h-1--密码可被任何人直接从合约存储中读取) | 密码可被任何人直接从合约存储中读取 | **高危** | 未修复 |
| [H-2](#h-2--setpassword-缺乏访问控制) | `setPassword` 缺乏访问控制 | **高危** | 未修复 |
| [I-1](#i-1--getpassword-的-natspec-声明了不存在的-param) | `getPassword` 的 NatSpec 声明了不存在的 `@param` | 提示级 | 未修复 |
| [I-2](#i-2--setpassword-的-natspec-记载了代码并未实现的访问控制保证) | `setPassword` 的 NatSpec 记载了代码并未实现的访问控制保证 | 提示级 | 未修复 |
| [I-3](#i-3--事件名-setnetpassword-拼写错误) | 事件名 `SetNetPassword` 拼写错误 | 提示级 | 未修复 |
| [I-4](#i-4--合约级注释块不是合法的-natspec) | 合约级注释块不是合法的 NatSpec | 提示级 | 未修复 |
| [I-5](#i-5--setnetpassword-未携带任何变更信息) | `SetNetPassword` 未携带任何变更信息 | 提示级 | 未修复 |
| [I-6](#i-6--owner-角色无法轮换) | owner 角色无法轮换 | 提示级 | 未修复 |
| [I-7](#i-7--接受空密码) | 接受空密码 | 提示级 | 未修复 |

**统计：** 2 高危 · 0 中危 · 0 低危 · 7 提示级。

---

## 4. 审计范围

### 4.1 范围内

| 文件 | 受审版本 SHA-256 |
| --- | --- |
| `src/PasswordStore.sol` | 见[附录 B.4](#b4-文件哈希) |

### 4.2 范围外

- `lib/` —— 第三方依赖（`forge-std`、`openzeppelin-contracts`、`chainlink-brownie-contracts`、`foundry-devops`）。
- `script/`、`test/` —— 部署与测试脚手架，仅作为佐证材料查阅。
- `Makefile`、`foundry.toml`、CI 配置，以及部署密钥的管理方式。

### 4.3 合约自述的功能目标

合约自身的 NatSpec 写明了其安全目标：

> *"This contract allows you to store a private password that others won't be able to see. You
> can update your password at any time."*
> （本合约允许你存储一个其他人无法看到的私密密码，并可随时更新。）

这句话是判定 [H-1](#h-1--密码可被任何人直接从合约存储中读取) 的标尺。

---

## 5. 执行摘要

`PasswordStore` 是一份刻意极简的教学合约，对外只暴露两个改状态接口：一个 setter、一个 getter，操作同一个
`string` 秘密。而合约赖以成立的两条安全假设，都站不住。

1. **公开区块链上不存在“保密”这件事。** `private` 可见性关键字是**编译期**构件，约束的是 Solidity 合约之间
   在语言层面的互访，与链上状态观察者能读到什么毫无关系。如 [H-1](#h-1--密码可被任何人直接从合约存储中读取)
   所示，密码仅凭一次 `eth_getStorageAt` 调用即可还原 —— 不需要私钥，不需要任何权限。由于这直接击穿了合约的
   全部存在意义，该发现定为高危，且**无法仅靠修改 Solidity 文件修复**，必须调整架构。
2. **setter 没有任何授权校验。** `setPassword` 对 `msg.sender` 不做任何检查，任何账户都能静默覆盖 owner 的
   密码（[H-2](#h-2--setpassword-缺乏访问控制)）。这是一处真实的实现缺陷，修复只需一行。

其余 7 条为文档与代码卫生层面的缺陷。它们单独均不可被利用，但
[I-1](#i-1--getpassword-的-natspec-声明了不存在的-param) 与
[I-2](#i-2--setpassword-的-natspec-记载了代码并未实现的访问控制保证) 值得单独留意，原因恰恰在于
**NatSpec 对安全性的过度承诺是“虚假安全感”的常见来源** —— 阅读自动生成文档的人，完全有理由认为
`setPassword` 已受 owner 限制，而事实并非如此。这与 [H-2](#h-2--setpassword-缺乏访问控制) 属于同一类错误，
只不过载体是散文而非代码。

### 5.1 结语 **[AI]**

面对 [H-1](#h-1--密码可被任何人直接从合约存储中读取)，最容易脱口而出的结论是“这合约该废弃重写”。对**这份**
合约而言，这确实是诚实的工程判断 —— 因为“除 owner 之外谁都看不到、而 owner 又通过公开 RPC 读回它”这个需求，
在透明账本上根本无法表达。对开发团队更有效的说法，不是“你的代码写错了”，而是“这个需求需要用平台真正能满足的
方式重新表述”。通常有两种改法：

- **存校验值，不存秘密。** 如果目标只是**校验**用户提交的密码，就存加盐且经过慢哈希（key stretching）的摘要
  再比对，明文永不落链。
- **存密文，不存明文。** 如果目标确实是**日后取回**，就在客户端用一把只有用户自己掌握的密钥加密，链上只存密文；
  同时应当**移除 view getter** —— 因为把解密密钥当作 calldata 广播出去，加密就白做了。

---

## 6. 审计方法

1. **人工源码走查**：通读范围内全部代码，逐一追踪每个外部入口点、其状态变更与存储占用。
2. **存储布局分析**：确定各状态变量所在槽位，并验证 `private` 是否影响可观测性。
3. **NatSpec 与实现的一致性比对**：把每一条文档声明与实际代码行为逐条对照。
4. **可执行的概念验证**：每一条高危发现都附带 `test/PasswordStorePOC.t.sol` 中可运行的 Foundry 测试，
   并在本地 `anvil` 节点上完成端到端复现。全部命令与逐字输出记录于[附录 B](#附录-b--复现日志)。
5. **严重等级评定**：依据[第 3 章](#3-风险等级标准)的矩阵判定。

---

## 7. 审计发现

---

### H-1 — 密码可被任何人直接从合约存储中读取

| | |
| --- | --- |
| **等级** | 高危 |
| **可能性** | 必然 —— 只需对链的读权限 |
| **影响** | 机密性完全丧失，合约既定目标被击穿 |
| **类别** | 架构 / 数据暴露 |
| **位置** | `src/PasswordStore.sol:19`（`string private s_password;`） |

#### 描述

公开区块链上的所有状态都是公开的。每个全节点都保存完整的状态树，任何 JSON-RPC 端点都能通过
`eth_getStorageAt` 把它读出来。Solidity 的 `private` 关键字管的是**编译期哪些合约可以引用该变量**，
它**不**对底层存储槽做任何加密、隐藏或访问限制。

因此 `s_password` 没有提供任何机密性。而合约却试图用 `getPassword` 里的 owner 检查来把守它：

```solidity
function getPassword() external view returns (string memory) {
    if (msg.sender != s_owner) {
        revert PasswordStore__NotOwner();
    }
    return s_password;
}
```

这个检查可以被轻易绕过。它约束的只是**ABI 层面**通向该值的路径，并不能把值从全网可读的状态树里拿掉。
攻击者根本不需要调用 `getPassword`，直接读槽位 `1` 即可。

另外，这里还存在一个与严重等级无关的事实性错误：合约中并不存在名为 `s_password` 的函数，取密码的是
`getPassword`。

#### 影响

任何一方 —— 无需密钥对、无需 Gas、无需与合约发生任何交互 —— 都能还原出明文密码。由于本合约唯一的用途就是
保守这个值的秘密，协议的核心安全属性等于完全不存在。这不是局部削弱，而是合约存在理由的整体失效。

#### 概念验证

提供两条相互独立的复现路径，均在受审版本上验证通过。

**PoC A —— 本地链上的原始存储读取（端到端）。**

```bash
# 1. 启动本地链
make anvil

# 2. 部署；部署脚本内部还会调用 setPassword("myPassword")
make deploy

# 3. 读取存储槽 1（槽 0 是 s_owner，槽 1 是 s_password）
cast storage 0x5fbdb2315678afecb367f032d93f642f64180aa3 1 --rpc-url http://127.0.0.1:8545
```

输出 —— 明文就在里面，右侧补零至 32 字节：

```
0x6d7950617373776f726400000000000000000000000000000000000000000014
```

```bash
# 4. 解码
cast parse-bytes32-string 0x6d7950617373776f726400000000000000000000000000000000000000000014
```

```
myPassword
```

末尾的 `0x14`（十进制 20）是 Solidity 的短字符串编码：长度不超过 31 字节的值，会把长度按 `length * 2`
写进槽的最低位字节。包含 `s_owner` 槽位以确认槽序的完整记录见[附录 B.1](#b1-端到端存储读取)。

**PoC B —— Foundry 回归测试。**

以下测试位于 `test/PasswordStorePOC.t.sol`，在受审版本上**全部通过** —— 这正是重点。第一条尤其说明问题：
它证明 owner 检查对 `getPassword` 确实生效（调用被 revert），而同一个调用者紧接着一行就从原始存储里读到了
完全相同的秘密。

```solidity
/// @notice H-1：`getPassword` 有访问控制，但它所守护的秘密可被任何人从合约存储中直接读出。
function test_POC_H1_access_control_is_not_confidentiality() public {
    vm.prank(OWNER);
    passwordStore.setPassword("myPassword");

    // 访问控制在 ABI 层面确实起作用……
    vm.prank(ATTACKER);
    vm.expectRevert(PasswordStore.PasswordStore__NotOwner.selector);
    passwordStore.getPassword();

    // ……但在存储层面完全无关紧要。
    bytes32 raw = vm.load(address(passwordStore), bytes32(uint256(1)));
    assertEq(_decodeShortString(raw), "myPassword");
}
```

另一条测试覆盖长度超过 31 字节的秘密 —— Solidity 会把这类值存到 `keccak256(slot)` 处而非内联，但同样可以被
完整还原：

```
[PASS] test_POC_H1_access_control_is_not_confidentiality() (gas: 44529)
[PASS] test_POC_H1_anyone_reads_password_from_raw_storage() (gas: 38205)
[PASS] test_POC_H1_long_password_is_equally_recoverable() (gas: 147194)
```

#### 修复建议

**必须调整合约架构。仅修改 `src/PasswordStore.sol` 无法修复本发现**，因为缺陷在于需求本身，而非实现。
按可靠性由高到低，有三个方向：

1. **存校验值而非秘密。** 若业务需求是**校验**用户提交的密码，就存 `keccak256(salt ‖ password)` —— 或者，
   考虑到人类可记忆的密码熵值偏低、可被离线暴力破解，改用在链下计算的慢哈希构造（如 PBKDF2 / argon2）。
   明文永不落链，也就无所谓“保密”了。
2. **链下加密，链上存密文。** 由客户端用一把源自用户链下掌握材料的密钥加密密码，链上只存密文。这样能保住
   “日后取回”的流程，代价是用户需要额外记住第二个秘密。
3. **这类需求干脆不要放在链上存。** 密钥库、密码管理器、客户端加密的 blob，才是秘密该待的地方。透明账本不是。

无论选哪条，都应当**移除返回秘密的 view getter**。一个返回明文（或解密材料）的读取函数本身就是一条外泄通道，
而且它会诱导用户把这段材料当作 calldata 广播进公开内存池。

#### 修复后验证

- 对修复后的合约遍历全部存储槽做 `vm.load` 扫描，断言没有任何值可由明文推导得出。
- 若采用方案 1 或 2，补一条测试：正确输入通过、错误输入失败，且秘密始终无法从状态中还原。

---

### H-2 — `setPassword` 缺乏访问控制

| | |
| --- | --- |
| **等级** | 高危 |
| **可能性** | 必然 —— 任何外部账户都能调用 |
| **影响** | 任何账户都可以覆盖 owner 的密码 |
| **类别** | 访问控制 |
| **位置** | `src/PasswordStore.sol:31` |

#### 描述

`setPassword` 被声明为 `external`，且对 `msg.sender` 不做任何校验：

```solidity
function setPassword(string memory newPassword) external {
    s_password = newPassword;
    emit SetNetPassword();
}
```

该函数自身的 NatSpec（*"This function allows only the owner to set a new password."*）以及合约的既定设计，
都描述了一个仅限 owner 的操作。而代码里一行都没实现。

根本原因是**缺少调用者校验**，而不是 `external` 这个关键字 —— 可见性与授权是两个相互独立的问题，
`external` 函数完全有能力校验自己的调用者。这个区分在写修复代码时很关键。

#### 影响

任何账户都能设置或替换已存储的密码。由此产生两个后果：

- **完整性丧失。** 合法 owner 的值被静默销毁。而且由于 `SetNetPassword` 不携带有效信息
  （[I-5](#i-5--setnetpassword-未携带任何变更信息)），这次覆盖在事件日志里同样观察不到。
- **对 owner 的拒绝服务。** 叠加缺失的访问控制后，owner 调用 `getPassword` 拿回的是攻击者控制的数据，
  且无从恢复原值。

该发现达到高危标准，因为合约自己文档化的保证，被无特权攻击者在无任何前置条件下即可击穿。

#### 概念验证

```solidity
/// @notice H-2：`setPassword` 不校验调用者，任何账户都能覆盖 owner 的密码。
function test_POC_H2_anyone_overwrites_password() public {
    vm.prank(OWNER);
    passwordStore.setPassword("owner-password");

    vm.prank(ATTACKER);
    passwordStore.setPassword("attacker-password");

    vm.prank(OWNER);
    assertEq(passwordStore.getPassword(), "attacker-password");
}
```

另有模糊测试变体确认对任意调用者均成立。两条测试均通过：

```
[PASS] test_POC_H2_anyone_overwrites_password() (gas: 43175)
[PASS] test_POC_H2_set_password_is_unrestricted_fuzz(address) (runs: 256, μ: 43957, ~: 43957)
```

#### 修复建议

在函数开头加入显式调用者校验，复用合约中已声明的 error：

```solidity
function setPassword(string memory newPassword) external {
    if (msg.sender != s_owner) {
        revert PasswordStore__NotOwner();
    }
    s_password = newPassword;
    emit SetNewPassword();
}
```

注意 error 标识符：合约声明的是 `PasswordStore__NotOwner`（**双下划线**）。若修复代码 revert 一个拼写不同的
error —— 例如本报告草稿中使用的 `PassWordStore_NotOwner` —— 是编译不过的。上线前请先确认修复代码真的能编译。

若后续出现第二个受限函数，`modifier onlyOwner` 是更易维护的形态。如果需要 owner 可转移，建议直接审计并采用
经过充分测试的实现（如 OpenZeppelin 的 `Ownable`），而不是自行造轮子。

#### 修复后验证

```solidity
function test_non_owner_cannot_set_password(address caller) public {
    vm.assume(caller != owner);
    vm.prank(caller);
    vm.expectRevert(PasswordStore.PasswordStore__NotOwner.selector);
    passwordStore.setPassword("attacker-password");
}
```

---

### I-1 — `getPassword` 的 NatSpec 声明了不存在的 `@param`

| | |
| --- | --- |
| **等级** | 提示级 |
| **位置** | `src/PasswordStore.sol:36-40` |

#### 描述

```solidity
/*
 * @notice This allows only the owner to retrieve the password.
 * @param newPassword The new password to set.
 */
function getPassword() external view returns (string memory) {
```

函数签名是 `getPassword()` —— 不接受任何参数。`@param newPassword` 这一行是从 `setPassword` 的文档复制
粘贴时残留的。

#### 影响

无运行时影响。问题在于：任何消费 NatSpec 的工具（`solc --userdoc`、Solidity 语言服务器、自动生成的文档站点、
阅读 ABI 的 AI agent）都会输出或推理一个并不存在的参数，产出误导性的签名与自动引用。在一份被当作教学范本的
代码库里，这类错误是会传染的。

#### 概念验证

不适用 —— 静态文档缺陷，没有可演示的运行时行为。

#### 修复建议

删除这行过期标签。既然函数无参数，只有 `@return` 是适用的标签：

```solidity
/**
 * @notice Allows the owner to retrieve the password.
 * @return The password previously stored by the owner.
 */
function getPassword() external view returns (string memory) {
```

---

### I-2 — `setPassword` 的 NatSpec 记载了代码并未实现的访问控制保证

| | |
| --- | --- |
| **等级** | 提示级 |
| **位置** | `src/PasswordStore.sol:27-30` |

#### 描述

`setPassword` 上的 NatSpec 写着 *"This function allows only the owner to set a new password."*
而代码中没有任何 owner 校验 —— 具体利用方式见 [H-2](#h-2--setpassword-缺乏访问控制)。

#### 影响

本身没有独立的运行时影响；本条是 [H-2](#h-2--setpassword-缺乏访问控制) 在文档侧的另一半。之所以单列，
是因为它的失效模式不同且值得命名：**文档中的错误安全声明，本身就是一种漏洞载体。** 审计员、集成方与自动化
工具普遍把 NatSpec 当作规格说明，再默认实现与之一致。这种虚假保证，恰好会在最需要被审视的地方压制审视。

#### 概念验证

不适用。

#### 修复建议

先修代码（[H-2](#h-2--setpassword-缺乏访问控制)），再修注释 —— 无论顺序如何，两者必须一致。若补上了校验，
现有措辞在把 "the owner" 更正为 "only the owner" 后即为准确。若出于某种原因确实意图允许无限制写入，
NatSpec 必须如实说明，同时合约级注释也必须停止声称机密性。

---

### I-3 — 事件名 `SetNetPassword` 拼写错误

| | |
| --- | --- |
| **等级** | 提示级 |
| **位置** | `src/PasswordStore.sol:21`，在 `:33` 处触发 |

#### 描述

```solidity
event SetNetPassword();
```

本意应为 `SetNewPassword`。`Net` 看起来是 `New` 的字母顺序颠倒。

#### 影响

无运行时影响。`SetNetPassword` 这个标识符属于合约 ABI 的一部分：它决定了事件的 topic 哈希，也决定
`eth_getLogs` 结果里显示的名称。由于声明处与触发处的拼写是一致的，合约本身能正常工作；代价由全部下游消费者承担
—— 索引器、subgraph、告警规则、看板，都必须把这个拼写错误编码进去，而且是**永久性的**，因为部署之后再改
topic 哈希，对它们而言属于破坏性变更。

#### 概念验证

不适用。

#### 修复建议

在声明处与触发处同时改名为 `SetNewPassword`，且要**赶在部署之前**，此时改动零成本。部署之后，改名即为 ABI
破坏性变更，需要协调索引器同步迁移；若协调成本不划算，就应在 ABI 说明里显式记录这个拼写错误，
免得后续集成方反复猜。

---

### I-4 — 合约级注释块不是合法的 NatSpec

| | |
| --- | --- |
| **等级** | 提示级 |
| **位置** | `src/PasswordStore.sol:4-9` |

#### 描述

```solidity
/*
 * @author not-so-secure-dev
 * @title PasswordStore
 * @notice This contract allows you to store a private password that others won't be able to see.
 * You can update your password at any time.
 */
contract PasswordStore {
```

该注释块以 `/*` 开头，而不是 `/**`。Solidity 的 NatSpec 解析器只承认 `/**`（以及 `///`）为文档注释。
整块内容 —— 包括 `@author`、`@title`、`@notice` 三个标签 —— 都被当作普通注释并被**编译器丢弃**，
不会出现在 ABI、`solc --userdoc` 或任何由源码生成的文档中。

同一缺陷也存在于第 27 行与第 36 行的函数级注释块上，它们同样使用了 `/*`。相比之下，
[I-1](#i-1--getpassword-的-natspec-声明了不存在的-param) 里那行过期的 `@param` 反倒是格式正确的 `/**`
NatSpec —— 这正是为什么唯独那一块会真正出现在生成的文档里，连同拼写错误一起。

#### 影响

无运行时影响。实际后果是：合约自述的安全目标 —— 也就是本报告在[第 4.3 节](#43-合约自述的功能目标)用作标尺的
那句话 —— 对所有读取源码的工具都是不可见的。自以为已经记录了合约设计的人，实际上什么机器可读的东西都没留下。

#### 概念验证

```bash
forge build
python3 -c "
import json
abi = json.load(open('out/PasswordStore.sol/PasswordStore.json'))
print([e for e in abi if e.get('type') == 'function'])"
# 检查 ABI 中是否含有引用合约级 notice 的 'docs' / userdoc 段落
```

生成的构建产物中，不含该注释块对应的任何 userdoc 条目。

#### 修复建议

把所有 `/*` 文档注释块提升为 `/**`：

```solidity
/**
 * @author not-so-secure-dev
 * @title PasswordStore
 * @notice Allows a user to store a password that others cannot see, and to update it at any time.
 */
contract PasswordStore {
```

同时请顺带重审 `@notice` 的文案：在
[H-1](#h-1--密码可被任何人直接从合约存储中读取) 成立的前提下，任何“其他人无法看到”的表述都不应被带进
修正后的文档里。**让文档变成机器可读的，前提是这份文档是真实的。**

---

### I-5 — `SetNetPassword` 未携带任何变更信息

| | |
| --- | --- |
| **等级** | 提示级 |
| **位置** | `src/PasswordStore.sol:21`、`:33` |

#### 描述

该事件不带任何参数。它只能表明 `setPassword` 被调用过，既不表明是谁调的，也不表明设了什么。

#### 影响

无运行时影响，也**不存在**机密性影响 —— 无论有没有这个事件，该值都能从存储中读到
（[H-1](#h-1--密码可被任何人直接从合约存储中读取)）。代价在于可观测性：链下监控无法区分一次合法的密码轮换
与一次越权覆盖，无法把变更归因到某个调用者，也无法审计该值的历史。叠加
[H-2](#h-2--setpassword-缺乏访问控制) 之后，一次无归属的覆盖，除了一条无参数日志之外不留任何痕迹。

#### 概念验证

不适用。

#### 修复建议

发出可观测性所需的信息 —— **但绝不要发出秘密本身**：

```solidity
event SetNewPassword(address indexed caller, uint256 indexed version);
```

把新密码作为事件参数发出是有害的：那等于把秘密发进日志流，它会永久留存且极易被检索，从而废掉为
[H-1](#h-1--密码可被任何人直接从合约存储中读取) 选定的任何机密性缓解方案。应当发出**行为主体**与一个单调递增的
版本号；若确实需要追踪值本身，就在链下比对相邻的存储快照。另需注意，Solidity 中 `string` 类型无法被 `indexed`，
所以天真地写 `indexed string newPassword` 是编译不过的。

---

### I-6 — owner 角色无法轮换

| | |
| --- | --- |
| **等级** | 提示级 |
| **位置** | `src/PasswordStore.sol:23-25` |

#### 描述

`s_owner` 仅在构造函数中赋值一次，此后永不被重新赋值。合约没有转移或放弃所有权的函数。

#### 影响

无直接可利用性。暴露面在于可用性与密钥卫生：指定的 owner 是永久的，因此密钥泄露后无法通过轮换角色来补救；
而 owner 私钥一旦丢失，`getPassword` 将对所有调用者永久 revert（密码无法再经由设计路径取得 —— 不过依据
[H-1](#h-1--密码可被任何人直接从合约存储中读取)，它仍可从存储中读到，这正是本条不构成高危可用性发现的原因）。

更合适的处理方式是把它作为一个需要明确做出的设计决策，而不是靠默认省略：对一个零价值教学合约而言，
不可变 owner 是站得住的；一旦牵涉真实价值或真实秘密，就站不住了。

#### 概念验证

不适用。

#### 修复建议

要么把不可变性作为有意选择记录下来，要么采用经过审计的所有权实现（如 OpenZeppelin `Ownable`）提供的
`transferOwnership` / `renounceOwnership`，而不是自行实现轮换逻辑。若决定加入轮换，优先选用 `Ownable2Step`
—— 单步转移若填错地址或转到了不受控地址，是无法挽回的。

---

### I-7 — 接受空密码

| | |
| --- | --- |
| **等级** | 提示级 |
| **位置** | `src/PasswordStore.sol:31` |

#### 描述

`setPassword` 对 `newPassword` 不做任何校验。传入空字符串会存入一个零长度值，而 `getPassword` 会把它当作
正常结果返回。仅凭返回类型，无法区分“从未设置过密码”与“设置了一个空密码”。

#### 影响

无直接可利用性，也无资金损失。后果是调用者可以静默清空已存的值，而 owner 的读取路径没有任何办法分辨
“被清空”和“合法地设为空”。任何把“`getPassword` 不 revert”等同于“密码存在”的集成方，都会被误导。

#### 概念验证

```solidity
function test_empty_password_is_indistinguishable_from_unset() public {
    assertEq(passwordStore.getPassword(), "");   // 从未设置过

    vm.prank(owner);
    passwordStore.setPassword("");
    assertEq(passwordStore.getPassword(), "");   // 空密码与之完全无法区分
}
```

#### 修复建议

若空密码没有意义，就显式拒绝：

```solidity
if (bytes(newPassword).length == 0) {
    revert PasswordStore__EmptyPassword();
}
```

否则，用布尔标志 `s_passwordSet` 显式记录状态，让消费方能区分两种情况。不要依赖字符串是否为空来充当哨兵值。

---

## 附录 A — 存储布局

| 槽位 | 变量 | 类型 | 说明 |
| --- | --- | --- | --- |
| `0` | `s_owner` | `address private` | 右对齐存放于 32 字节字中，高 12 字节为零。 |
| `1` | `s_password` | `string private` | 短字符串（≤ 31 字节）内联存放：最低位字节 = `length * 2`。更长字符串：最低位字节 = `length * 2 + 1`，数据从 `keccak256(uint256(1))` 起连续存放。 |

任何节点运营者都能通过 `eth_getStorageAt` 读取上述两个槽位，且无需任何认证。`private` 只影响 Solidity 编译期的
可见性，对上表毫无影响。

---

## 附录 B — 复现日志

环境：Foundry `forge 1.7.1`（`4072e487`）、`solc 0.8.18`、WSL2 Ubuntu、`anvil` 监听
`127.0.0.1:8545`。以下输出均为逐字转录。

### B.1 端到端存储读取

```console
$ forge script script/DeployPasswordStore.s.sol:DeployPasswordStore --rpc-url http://127.0.0.1:8545 --private-key $ANVIL_KEY --broadcast
ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

$ cast storage 0x5fbdb2315678afecb367f032d93f642f64180aa3 0 --rpc-url http://127.0.0.1:8545
0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266   # 槽 0：s_owner

$ cast storage 0x5fbdb2315678afecb367f032d93f642f64180aa3 1 --rpc-url http://127.0.0.1:8545
0x6d7950617373776f726400000000000000000000000000000000000000000014   # 槽 1：s_password

$ cast parse-bytes32-string 0x6d7950617373776f726400000000000000000000000000000000000000000014
myPassword
```

部署地址 `0x5fbdb2315678afecb367f032d93f642f64180aa3` 对标准 `anvil` 助记词的首次 `CREATE` 而言是确定性的；
`s_owner` 解码后即第一个默认账户，确认了槽位顺序。

### B.2 原有测试套件

```console
$ forge test
Ran 3 tests for test/PasswordStore.t.sol:PasswordStoreTest
[PASS] test_anyone_can_set_password(address) (runs: 256, μ: 25702, ~: 25712)
[PASS] test_non_owner_reading_password_reverts() (gas: 13469)
[PASS] test_owner_can_set_password() (gas: 24145)
Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 16.14ms
```

### B.3 概念验证套件

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

这些测试通过，本身就是证据。只有当对应的测试被反转成“断言失败”时，才说明修复真正生效。

### B.4 文件哈希

```console
# 受审版本 src/PasswordStore.sol
$ git show 2e8f81e263b3a9d18fab4fb5c46805ffc10a9990:src/PasswordStore.sol | sha256sum
```

*（请在本地自行复现 —— 该哈希与环境无关，而针对固定提交执行 `git show` 才是权威来源。此处刻意不转录哈希值，
以免报告内容与仓库实际状态出现不一致。）*

---

## 附录 C — 工具链与 AI 来源说明 **[AI]**

| 项目 | 内容 |
| --- | --- |
| 撰写者 | Claude Code（Anthropic） |
| 人工复核 | BOXU OU（`@gongzai0208-afk`） |
| 复现步骤来源 | Cyfrin Updraft ——《Security & Auditing》PasswordStore 模块 |
| 验证方式 | [附录 B](#附录-b--复现日志)中每条命令均已实际执行，输出逐字转录 |

**作为作品集材料，这份报告应当怎样被阅读。** 发现数量少、目标合约又刻意存在漏洞 —— 这是教学靶场的固有属性。
本文档真正想展示的是**方法**：锁定版本；把原始受审提交与本地加了批注的工作副本区分开；给出可运行的证明而非
叙述性的证明；区分“打补丁就能修”的缺陷与“必须做架构决策”的缺陷；以及在[第 2 章](#2-免责声明)中如实说明
本次审计的边界。AI 产出的审计报告，诚实的短板在于：它没有跟客户就某条发现进行过拉锯，没有被质疑过严重等级，
也没有经历过修复复评。读者应当据此权衡。
