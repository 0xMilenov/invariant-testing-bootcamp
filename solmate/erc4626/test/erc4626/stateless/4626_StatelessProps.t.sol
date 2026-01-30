pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";

import {MockERC20} from "../../../src/mocks/MockERC20.sol";
import {MockERC4626} from "../../../src/mocks/MockERC4626.sol";

contract ERC4626_StatelessProps is Test {
    MockERC20 internal asset;
    MockERC4626 internal vault;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        asset = new MockERC20("Asset", "AST", 18);
        vault = new MockERC4626(asset, "Vault Share", "vAST");

        asset.mint(alice, 1_000_000e18);
        asset.mint(bob, 1_000_000e18);

        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        asset.approve(address(vault), type(uint256).max);
    }

    // Stateless property 1 - Deposit path
    function test_fuzz_previewDeposit_matches_deposit_orReverts(uint256 assetsIn) public {

      uint256 initialTotalAssets = vault.totalAssets();
      
      assetsIn = bound(assetsIn, 0, asset.balanceOf(alice));

      uint256 expectedShares = vault.previewDeposit(assetsIn);

      if (expectedShares == 0) {
        vm.startPrank(alice);
        vm.expectRevert("ZERO_SHARES");
        vault.deposit(assetsIn, alice);
        vm.stopPrank();
      } else {
        vm.startPrank(alice);
        vault.deposit(assetsIn, alice);
        assertEq(vault.balanceOf(alice), expectedShares);
        vm.stopPrank();
      }

      assertEq(vault.totalAssets(), initialTotalAssets + assetsIn);

    }

    // Stateless property 2 - mint path
    function test_fuzz_previewMint_matches_mint(uint256 sharesOut) public {

      // tiny deposit to hit the 'supply > 0'
      vm.startPrank(bob);
      vault.deposit(1, bob);
      vm.stopPrank();

      uint256 reasonableMaxAmount = 1_000_000e18;

      sharesOut = bound(sharesOut, 0, reasonableMaxAmount);

      // pre-state AFTER the seed deposit
      uint256 supplyBefore = vault.totalSupply();
      uint256 aliceSharesBefore = vault.balanceOf(alice);
      uint256 assetsBefore = vault.totalAssets();

      uint256 expectedAssets = vault.previewMint(sharesOut);

      if (expectedAssets > asset.balanceOf(alice)) return;

      vm.startPrank(alice);
      uint256 assetsIn = vault.mint(sharesOut, alice);
      vm.stopPrank();

      assertEq(assetsIn, expectedAssets);

      assertEq(vault.totalSupply(), supplyBefore + sharesOut);
      assertEq(vault.balanceOf(alice), aliceSharesBefore + sharesOut);
      assertEq(vault.totalAssets(), assetsBefore + assetsIn);
    }

    function test_fuzz_preview_and_convert_consistency(uint256 assetsIn, uint256 sharesIn) public view {
      assertEq(vault.previewDeposit(assetsIn), vault.convertToShares(assetsIn));
      assertEq(vault.previewRedeem(sharesIn), vault.convertToAssets(sharesIn));
    }

    function test_limits_consistency() public view {
      assertEq(vault.maxDeposit(alice), type(uint256).max);
      assertEq(vault.maxMint(alice), type(uint256).max);
      assertEq(vault.maxRedeem(alice), vault.balanceOf(alice));
      assertEq(vault.maxWithdraw(alice), vault.convertToAssets(vault.balanceOf(alice)));
    }
}