1.Convince the protocal this is an issue
2.How bad this issue is
3.How to fix the issue

//  TITLE (Root Cause(根本原因) + impact)
### [S-HIGH] Varibles stored in storage on-chain is visible to anyone , no matter the solidity visibility keyword meaning the password is not the parvite password

or clearly:
### [S-HIGH!] Storing the password on-chain makes it visable to anyone , and no longer private

**Description:** All data stored on/-chain is vosable to anyone,and can be read directly from the blockchain. The `PasswordStore::s_password` variable is intended to be a private varible and only asscessed through the `PasswordStore::s_password`function, which is intended to be only called by the owner of the contract.

We show one such method of reading any data off chain below.

**Impact:**  Anyone can read the private password, severly breaking the function of the protocal. 

**Proof of Concept:** (Proof of Code) //对于竞技审计 或者面对缺乏经验初级的开发人员团队，在这里提供这些证据
The below test case shows how anyone can read the password directly from the blockchain.

1.Creat a locally running chain
```bash
make anvil
```

2.Deploy the contract to the chain
```
make deploy
```
3.Run the storage tool

We use `1` beacuse that's the storage of `s_password` in the contract.
```
cast storage <ADDRESS_HERE> 1 --rcp-url http://127.0.0.1:8545
```

You'll get an output that looks like this:
`0x6d7950617373776f726400000000000000000000000000000000000000000014`

You can parse that hex to a string with //你可以用下面这个工具把这段十六进制（hex）解析成字符串
```
cast parse-bytes32-string 0x6d7950617373776f726400000000000000000000000000000000000000000014
```

And get output
```
myPassword
```

**Recommended Mitigation:** （翻译：缓解措施）

EN:  Due to this, the overall architecture of the contract should be rethought.One could encrypt the password off-chain, and then store the encrypted password on-chain.This would require the user to remember another password off-chain to decrypt the password. However, you'd also likely want to remove the view function as you won't want the user to accidentally send a transaction with the password that decrypts your password.

CN：正因如此，我们需要重新考量这份合约的整体架构。可以将密码在链外加密，再把加密后的密码存储到链上。这种方案要求用户在链外记住另一个密码，用于解密（链上存储的）密码。不过，你大概率还需要移除view函数，因为不希望用户实际发送一个包含解密你密码的密码的交易。

ps：As a security researcher,it's hard to say:hey this protocol should be scrapped. We want do our best to educate the developers so they know how to move forward here




### [S-#] `PasswordStore::setPassword` has no access controls, meaning a non-owner could change the password 
**Description:** `PasswordStore::setPassword` function is set to be an `external` function. The natspec of the function and overall purpose of the smart contract is that `The function allows only owner to set a new Password.`
CN:`PasswordStore::setPassword` 函数被定义为 `external` 函数。该函数的 NatSpec 注释以及这份智能合约的整体设计目标写明：该函数仅允许合约所有者设置新密码。

``` javascript
function setPassword(string memory newPassword) external {
$>>    //@audit--There is no assess controls
        s_password = newPassword;
        emit SetNetPassword();
    }
```
**Impact:** Anyone can set/change the passwords of the contract,severly breaking the contract intended functionality.

**Proof of Concept:** Add the following to the `PasswordStore.t.sol` test file.

<details>
<summary>Code</summary>

```javascript
function test_anyone_can_set_password(address randomAddress) public {
        vm.assume(randomAddress != owner);
        vm.prank(randomAddress);
        string memory expectedPassword = "myNewPassword";
        passwordStore.setPassword(expectedPassword);

        vm.prank(owner);
        string memory actualPassword = passwordStore.getPassword();
        assertEq(actualPassword,expectedPassword);
    }
```

</details>


**Recommended Mitigation:** Add an access control condition to the set password function  (在set password函数中添加一个访问控制条件)

```javascript
if(msg.sender!=s_owner){
    revert PassWordStore_NotOwner();
}

```


### [S-#] `PassWordStore::getPassword` natspec indicates a parameter that doesn't exist , causing the natspec to be incorrect 

**Description:**

```javascript
   /*
     * @notice This allows only the owner to retrieve the password.
    //@audit their is no newPassword parameter in this funtion
     * @param newPassword The new password to set.
     */
    function getPassword() external view returns (string memory) {
```
The`PassWordStore::getPassWord` function signature(签名) is `getPassWord()` while the natspec say it should be `getPassWord(string)`.


**Impact:** The natspec is incorrect.

**Proof of Concept:**

**Recommended Mitigation:** 