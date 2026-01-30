pragma solidity >=0.8.0;

import {MockERC20} from "../../../src/mocks/MockERC20.sol";
import {MockERC4626} from "../../../src/mocks/MockERC4626.sol";

contract ERC4626Echidna {

  MockERC20 public asset;
  MockERC4626 public vault;

  Actor public alice;
  Actor public bob;

  uint256 public initialTrackedAssetSum;

  constructor() {
    asset = new MockERC20("Asset", "AST", 18);
    vault = new MockERC4626(asset, "Vault Share", "vAST");

    alice = new Actor(asset, vault);
    bob = new Actor(asset, vault);

    asset.mint(address(alice), 1_000_000e18);
    asset.mint(address(bob), 1_000_000e18);

    initialTrackedAssetSum =
      asset.balanceOf(address(alice)) +
      asset.balanceOf(address(bob)) +
      asset.balanceOf(address(vault));
  }

  function act_deposit(uint256 assets, uint8 who) external {

    Actor a = _actor(who);

    if (assets == 0) return;
    if (assets > asset.balanceOf(address(a))) assets = asset.balanceOf(address(a));
    if (vault.previewDeposit(assets) == 0) return;
    vault.deposit(assets, address(a));
  }

  function act_mint(uint256 shares, uint8 who) external {
    Actor a = _actor(who);

    shares = _min(shares, 1_000_000e18);

    uint256 assetsIn = vault.previewMint(shares);
    if (shares == 0) return;
    if (assetsIn == 0) return;

    uint256 bal = asset.balanceOf(address(a));
    if (assetsIn > bal) return;

    a.mint(shares);
  }

  // shares to avoid rounding errors
  function act_withdraw(uint256 shares, uint8 who) external {

    Actor a = _actor(who);

    uint256 maxShares = vault.maxRedeem(address(a));
    shares = _min(shares, maxShares);
    if (shares == 0) return;

    uint256 assetsOut = vault.convertToAssets(shares);
    if (assetsOut == 0) return;

    a.withdraw(assetsOut);
  }

  function act_redeem(uint256 shares, uint8 who) external {

    Actor a = _actor(who);

    shares = _min(shares, vault.maxRedeem(address(a)));
    if (shares == 0) return;
    if (vault.previewRedeem(shares) == 0) return;
    vault.redeem(shares, address(a), address(a));
  }

  // For comparing with foundry
  // function act_cheat_sendAssetsAway(uint256 amount, uint8 who) external {
  //   Actor a = _actor(who);

  //   uint256 bal = asset.balanceOf(address(a));
  //   amount = _min(amount, bal);
  //   if (amount == 0) return;

  //   a.transferAsset(address(0xDEAD), amount);
  // }

  function echidna_totalAssets_matches_balance() external view returns (bool) {
    return vault.totalAssets() == asset.balanceOf(address(vault));
  }

  function echidna_totalSupply_equals_sum_of_actorBalances() external view returns (bool) {
    uint256 sumShares = vault.balanceOf(address(alice)) + vault.balanceOf(address(bob));
    return vault.totalSupply() == sumShares;
  }

  // function echidna_tracked_asset_conservation() external view returns (bool) {
  //   uint256 currentSum =
  //     asset.balanceOf(address(alice)) +
  //     asset.balanceOf(address(bob)) +
  //     asset.balanceOf(address(vault));
  //   return currentSum == initialTrackedAssetSum;
  // }

  // internal helper funcs
  function _min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }

  function _actor(uint8 who) internal view returns (Actor) {
    return (who % 2 == 0) ? alice : bob;
  }
}

contract Actor {
  MockERC20 public asset;
  MockERC4626 public vault;

  constructor(MockERC20 _asset, MockERC4626 _vault) {
    asset = _asset;
    vault = _vault;
    asset.approve(address(vault), type(uint256).max);
  }

  function deposit(uint256 assets) external {
    vault.deposit(assets, address(this));
  }

  function mint(uint256 shares) external {
    vault.mint(shares, address(this));
  }

  function withdraw(uint256 assets) external {
    vault.withdraw(assets, address(this), address(this));
  }

  function redeem(uint256 shares) external {
    vault.redeem(shares, address(this), address(this));
  }

  function transferAsset(address to, uint256 amount) external {
    asset.transfer(to, amount);
  }
  
  function shareBalance() external view returns (uint256) {
    return vault.balanceOf(address(this));
  }
}