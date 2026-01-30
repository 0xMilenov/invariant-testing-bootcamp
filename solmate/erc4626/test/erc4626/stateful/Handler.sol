pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";

import {MockERC20} from "../../../src/mocks/MockERC20.sol";
import {MockERC4626} from "../../../src/mocks/MockERC4626.sol";

contract Handler is Test {
    MockERC20 internal asset;
    MockERC4626 internal vault;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    constructor(MockERC20 _asset, MockERC4626 _vault, address _alice, address _bob) {
        asset = _asset;
        vault = _vault;
        alice = _alice;
        bob = _bob;

        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        asset.approve(address(vault), type(uint256).max);
    }

    function _actor(uint8 i) internal view returns (address) {
      return (i % 2 == 0) ? alice : bob;
    }

    function deposit(uint256 assets, uint8 actorIndex) public {
      address a = _actor(actorIndex);

      uint256 bal = asset.balanceOf(a);
      assets = bound(assets, 0, bal);

      if (vault.previewDeposit(assets) == 0)  return;

      vm.prank(a);
      vault.deposit(assets, a);
    }

    function mint(uint256 shares, uint8 actorIndex) external {
      address a = _actor(actorIndex);

      shares = bound(shares, 0, 1_000_000e18);

      uint256 assetsIn = vault.previewMint(shares);
      if (assetsIn == 0) return;
      if (assetsIn > asset.balanceOf(a)) return;

      vm.prank(a);
      vault.mint(shares, a);
    }

    function withdraw(uint256 shares, uint8 actorIndex) external {
      address a = _actor(actorIndex);

      uint256 maxShares = vault.maxRedeem(a);
      shares = bound(shares, 0, maxShares);
      if (shares == 0) return;

      uint256 assets = vault.convertToAssets(shares); // rounds down
      if (assets == 0) return;

      vm.prank(a);
      vault.withdraw(assets, a, a);
    }

    function redeem(uint256 shares, uint8 actorIndex) external {
      address a = _actor(actorIndex);

      uint256 maxShares = vault.maxRedeem(a);
      shares = bound(shares, 0, maxShares);

      if (shares == 0) return;
      if (vault.previewRedeem(shares) == 0) return;

      vm.prank(a);
      vault.redeem(shares, a, a);
    }

    // This breaks asset-conservation invariants and its kept to learn shrinking + selector exclusion
    function cheat_sendAssetsAway(uint256 amount, uint8 actorIndex) external {
      address a = _actor(actorIndex);
      uint256 bal = asset.balanceOf(a);
      amount = bound(amount, 0, bal);
      if (amount == 0) return;

      vm.prank(a);
      asset.transfer(address(0xDEAD), amount);
    }

}