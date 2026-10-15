// SPDX-License-Identifier: MIT
pragma solidity 0.8.18; 

/*
 * @author not-so-secure-dev
 * @title PasswordStore
 * @notice This contract allows you to store a private password that others won't be able to see. 
 * You can update your password at any time.
 */
contract PasswordStore {
 //error ,never search for a password in a smart contract, this is not secure.    
    error PasswordStore__NotOwner();



    address private s_owner; //0
     //audit the s_password variable is not actually private!
    //@audit This is not the safe place to secure your password, anyone can read the password from the blockchain. 
    string private s_password; //1 

    event SetNetPassword();

    constructor() {
        s_owner = msg.sender;
    }

    /*
     * @notice This function allows only the owner to set a new password.
     * @param newPassword The new password to set.
     */
    function setPassword(string memory newPassword) external {
        s_password = newPassword;
        emit SetNetPassword();
    }

    /*
     * @notice This allows only the owner to retrieve the password.
    //@audit their is no newPassword parameter in this funtion
     * @param newPassword The new password to set.
     */
    function getPassword() external view returns (string memory) {
        if (msg.sender != s_owner) {
            revert PasswordStore__NotOwner();
        }
        return s_password;
    }
}
