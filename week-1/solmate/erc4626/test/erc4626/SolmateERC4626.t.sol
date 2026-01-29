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

    //////////////////////////////////////////////////////////////
    ////////////////////// WITHDRAW & REDEEM /////////////////////
    //////////////////////////////////////////////////////////////

    function test_withdraw_burnsShares_andEmitsWithdrawEvent() public {

        uint256 assets = 100e18;
        uint256 shares = vault.previewWithdraw(assets);

        vm.startPrank(alice);

        vault.deposit(assets, alice);
        assertEq(vault.balanceOf(alice), shares);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, alice, alice, assets, shares);
        uint256 sharesBurned = vault.withdraw(assets, alice, alice);

        assertEq(sharesBurned, shares);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(asset.balanceOf(alice), 1_000_000e18);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);

        vm.stopPrank();
    }

    function test_withdraw_nonOwner_infinteApproval() public {

        uint256 initialAssetBalanceOfBob = asset.balanceOf(bob);

        uint256 assets = 100e18;
        uint256 shares = vault.previewWithdraw(assets);

        vm.startPrank(alice);
        vault.approve(bob, type(uint256).max);

        vault.deposit(assets, alice);

        assertEq(vault.balanceOf(alice), shares);

        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit Withdraw(bob, bob, alice, assets, shares);
        uint256 sharesBurned = vault.withdraw(assets, bob, alice);

        assertEq(vault.allowance(alice, bob), type(uint256).max);

        assertEq(sharesBurned, shares);
        assertEq(vault.balanceOf(bob), 0);
        assertEq(asset.balanceOf(bob), assets + initialAssetBalanceOfBob);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);

        vm.stopPrank();
    }

    function test_withdraw_nonOwner_concreteApproval() public {
        
        uint256 initialAssetBalanceOfBob = asset.balanceOf(bob);

        uint256 assets = 100e18;
        uint256 shares = vault.previewWithdraw(assets);

        vm.startPrank(alice);
        vault.approve(bob, shares); // concrete approval

        vault.deposit(assets, alice);

        assertEq(vault.balanceOf(alice), shares);

        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit Withdraw(bob, bob, alice, assets, shares);
        uint256 sharesBurned = vault.withdraw(assets, bob, alice);

        assertEq(vault.allowance(alice, bob), 0); // approval is burned

        assertEq(sharesBurned, shares);
        assertEq(vault.balanceOf(bob), 0);
        assertEq(asset.balanceOf(bob), assets + initialAssetBalanceOfBob);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);

        vm.stopPrank();
    }

    function test_redeem_burnsShares_andEmitsRedeemEvent() public {
        uint256 shares = 100e18;
        uint256 expectedAssets = vault.previewRedeem(shares);

        vm.startPrank(alice);

        vault.deposit(expectedAssets, alice);
        assertEq(vault.balanceOf(alice), shares);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, alice, alice, expectedAssets, shares);
        uint256 assetsBurned = vault.redeem(shares, alice, alice);

        assertEq(assetsBurned, expectedAssets);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(asset.balanceOf(alice), 1_000_000e18);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);

        vm.stopPrank();
    }

    function test_redeem_withDifferentReceiver() public {
        uint256 shares = 100e18;
        uint256 expectedAssets = vault.previewRedeem(shares);
        uint256 initialAssetBalanceOfBob = asset.balanceOf(bob);

        vm.startPrank(alice);
        vault.deposit(expectedAssets, alice);
        assertEq(vault.balanceOf(alice), shares);

        vault.approve(bob, shares);

        vm.startPrank(bob);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(bob, bob, alice, expectedAssets, shares);
        uint256 assetsBurned = vault.redeem(shares, bob, alice);

        assertEq(assetsBurned, expectedAssets);
        assertEq(vault.balanceOf(bob), 0);
        assertEq(asset.balanceOf(bob), expectedAssets + initialAssetBalanceOfBob);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);

        vm.stopPrank();
    }

    function test_redeem_nonOwner_infinteApproval() public {
        uint256 shares = 100e18;
        uint256 expectedAssets = vault.previewRedeem(shares);
        uint256 initialAssetBalanceOfBob = asset.balanceOf(bob);

        vm.startPrank(alice);
        vault.deposit(expectedAssets, alice);
        assertEq(vault.balanceOf(alice), shares);

        vault.approve(bob, type(uint256).max);

        vm.startPrank(bob);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(bob, bob, alice, expectedAssets, shares);
        uint256 assetsBurned = vault.redeem(shares, bob, alice);

        assertEq(vault.allowance(alice, bob), type(uint256).max); // same

        assertEq(assetsBurned, expectedAssets);
        assertEq(vault.balanceOf(bob), 0);
        assertEq(asset.balanceOf(bob), expectedAssets + initialAssetBalanceOfBob);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);

        vm.stopPrank();
    }

    function test_redeem_nonOwner_concreteApproval() public {
        uint256 shares = 100e18;
        uint256 expectedAssets = vault.previewRedeem(shares);
        uint256 initialAssetBalanceOfBob = asset.balanceOf(bob);

        vm.startPrank(alice);
        vault.deposit(expectedAssets, alice);
        assertEq(vault.balanceOf(alice), shares);

        vault.approve(bob, shares); // concrete approval

        vm.startPrank(bob);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(bob, bob, alice, expectedAssets, shares);
        uint256 assetsBurned = vault.redeem(shares, bob, alice);

        assertEq(vault.allowance(alice, bob), 0); // approval is burned

        assertEq(assetsBurned, expectedAssets);
        assertEq(vault.balanceOf(bob), 0);
        assertEq(asset.balanceOf(bob), expectedAssets + initialAssetBalanceOfBob);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);

        vm.stopPrank();
    }

    function test_redeem_reverts_ZERO_ASSETS_ifSharesAreZero() public {
        vm.startPrank(alice);

        vault.deposit(100e18, alice);
        assertGt(vault.totalSupply(), 0);

        asset.burn(address(vault), asset.balanceOf(address(vault)));
        assertEq(vault.totalAssets(), 0);

        vm.expectRevert("ZERO_ASSETS");
        vault.redeem(1, alice, alice);

        vm.stopPrank();
    }

    function test_maxWithdraw_returnsBalanceOfOwner() public {

        uint256 maxWithdraw = vault.maxWithdraw(alice);
        assertEq(maxWithdraw, vault.balanceOf(alice));

    }

    function test_maxRedeem_returnsBalanceOfOwner() public {
        uint256 maxRedeem = vault.maxRedeem(alice);
        assertEq(maxRedeem, vault.balanceOf(alice));
    }

    function test_convertToAssets_returnsExpectedAssets() public {
        uint256 shares = 100e18;
        uint256 expectedAssets = vault.previewRedeem(shares);

        vm.startPrank(alice);
        vault.deposit(expectedAssets, alice);
        assertEq(vault.balanceOf(alice), shares);

        uint256 assets = vault.convertToAssets(shares);
        assertEq(assets, expectedAssets);
    }

    function test_convertToShares_returnsExpectedShares() public {
        uint256 assets = 100e18;
        uint256 expectedShares = vault.previewDeposit(assets);

        vm.startPrank(alice);
        vault.deposit(assets, alice);
        assertEq(vault.balanceOf(alice), expectedShares);

        uint256 shares = vault.convertToShares(assets);
        assertEq(shares, expectedShares);

        vm.stopPrank();
    }

}
