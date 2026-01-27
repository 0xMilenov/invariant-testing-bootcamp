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
    address internal bob = address(0xB0B);

    event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

    function setUp() public {
        asset = new MockERC20("Asset", "AST", 18);
        vault = new MockERC4626(asset, "Vault Share", "vAST");

        asset.mint(alice, 1_000_000e18);
        asset.mint(bob, 1_000_000e18);

        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
    }

    //////////////////////////////////////////////////////////////
    ////////////////////// DEPOSIT & MINT ////////////////////////
    //////////////////////////////////////////////////////////////

    function test_deposit_mintsShares_andEmitsDepositEvent() public {
        uint256 assets = 100e18;

        vm.startPrank(alice);

        assertEq(asset.balanceOf(alice), 1_000_000e18);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSupply(), 0);

        uint256 expectedShares = vault.previewDeposit(assets);

        vm.expectEmit(true, true, false, true);
        emit Deposit(alice, alice, assets, expectedShares);
        uint256 shares = vault.deposit(assets, alice);

        // On first deposit is 1-1, so shares = assets
        assertEq(shares, assets);
        assertEq(vault.balanceOf(alice), shares);
        assertEq(asset.balanceOf(alice), 1_000_000e18 - assets);
        assertEq(vault.totalSupply(), shares);
        assertEq(vault.totalAssets(), assets);

        vm.stopPrank();
    }

    function test_deposit_reverts_ZERO_SHARES_ifAssetsAreZero() public {
        vm.startPrank(alice);

        vm.expectRevert("ZERO_SHARES");
        vault.deposit(0, alice);

        vm.stopPrank();
    }

    function test_deposit_reverts_ZERO_SHARES_becauseOfRoundingDown() public {
        vm.startPrank(alice);

        vault.deposit(1, alice);

        asset.transfer(address(vault), 1e18);

        vm.expectRevert("ZERO_SHARES");
        vault.deposit(1, alice);

        vm.stopPrank();
    }

    function test_deposit_reverts_TRANSFER_FROM_FAILED_ifSenderDoesNotHaveEnoughAssets() public {
        vm.startPrank(alice);

        vm.expectRevert("TRANSFER_FROM_FAILED");
        vault.deposit(1_000_001e18, alice);

        vm.stopPrank();
    }

    function test_mint_supplyZero_then_supplyNonZero() public {
        vm.startPrank(alice);

        // first supply -> supply = 0
        uint256 shares1 = 100e18;
        uint256 expectedAssets1 = vault.previewMint(shares1);

        vm.expectEmit(true, true, false, true);
        emit Deposit(alice, alice, expectedAssets1, shares1);

        uint256 assets1 = vault.mint(shares1, alice);

        assertEq(assets1, expectedAssets1);
        assertEq(vault.totalSupply(), shares1);

        // second supply -> supply > 0
        uint256 shares2 = 100e18;
        uint256 expectedAssets2 = vault.previewMint(shares2);

        uint256 assets2 = vault.mint(shares2, alice);

        assertEq(assets2, expectedAssets2);
        assertEq(vault.balanceOf(alice), shares1 + shares2);

        vm.stopPrank();
    }

    function test_mint_reverts_TRANSFER_FROM_FAILED_ifSenderDoesNotHaveEnoughAssets() public {
        vm.startPrank(alice);

        vm.expectRevert("TRANSFER_FROM_FAILED");
        vault.mint(1_000_001e18, alice);

        vm.stopPrank();
    }

    function test_maxDeposit_returnsMaxInt() public {

        uint256 maxDeposit = vault.maxDeposit(alice);

        assertEq(maxDeposit, type(uint256).max);

    }

    function test_maxMint_returnsMaxInt() public {

        uint256 maxMint = vault.maxMint(alice);

        assertEq(maxMint, type(uint256).max);

    }
}
