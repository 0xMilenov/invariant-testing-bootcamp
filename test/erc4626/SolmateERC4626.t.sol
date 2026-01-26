// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";

import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockERC4626} from "../../src/mocks/MockERC4626.sol";

/// @notice ERC4626 test using Solmate as a reference
contract SolmateERC4626_Test is Test {
    MockERC20 internal asset;
    MockERC4626 internal vault;

    address internal alice = address(0xA11CE);

    function setUp() public {
        asset = new MockERC20("Asset", "AST", 18);
        vault = new MockERC4626(asset, "Vault Share", "vAST");

        asset.mint(alice, 1_000_000e18);

        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
    }

    function test_placeholder() public {
        assertTrue(address(vault) != address(0));
    }
}
