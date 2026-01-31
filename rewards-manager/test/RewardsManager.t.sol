pragma solidity 0.8.24;

import "forge-std/Test.sol";

import {RewardsManager} from "../src/RewardsManager.sol";
import {MockVault} from "./mocks/MockVault.sol";
import {MintableERC20} from "./mocks/MintableERC20.sol";
import {FeeOnTransferERC20} from "./mocks/FeeOnTransferERC20.sol";

contract RewardsManagerTest is Test {
  RewardsManager internal rewardsManager;
  MockVault internal vault;

  MintableERC20 internal rewardToken;
  FeeOnTransferERC20 internal fotRewardToken;

  address internal sponsor = address(0xABCD);

  address internal alice = address(0xA11CE);
  address internal bob = address(0xB0B);

  address internal fotFeeCollector = address(0xFEED);

  function setUp() external {
    vm.warp(1_700_000_000);

    rewardsManager = new RewardsManager();
    vault = new MockVault(address(rewardsManager));

    rewardToken = new MintableERC20("Reward Token", "RWD", 18);
    fotRewardToken = new FeeOnTransferERC20("FOT Reward Token", "FOTRWD", 18, 500, fotFeeCollector); // 5% fee


    // vm.prank(sponsor);
    // fotRewardToken.mint(sponsor, type(uint256).max);

    // vm.prank(alice);
    // fotRewardToken.approve(address(rewardsManager), type(uint256).max);
  }

  ///////////////////////////// HELPERS /////////////////////////////

  function _epoch(uint256 epochId) internal view returns (RewardsManager.Epoch memory epoch) {
    epoch = rewardsManager.getEpochData(epochId);
  }

  function _warpToEpochStart(uint256 epochId) internal {
    RewardsManager.Epoch memory epoch = _epoch(epochId);
    vm.warp(epoch.startTimestamp);
  }

  function _warpToEpochStartPlus1(uint256 epochId) internal {
    RewardsManager.Epoch memory epoch = _epoch(epochId);
    vm.warp(epoch.startTimestamp + 1);
  }

  function _warpToEpochStartPlus100(uint256 epochId) internal {
    RewardsManager.Epoch memory epoch = _epoch(epochId);
    vm.warp(epoch.startTimestamp + 100);
  }

  function _warpToEpochStartPlus200(uint256 epochId) internal {
    RewardsManager.Epoch memory epoch = _epoch(epochId);
    vm.warp(epoch.startTimestamp + 200);
  }

  function _warpToEpochEndMinus1(uint256 epochId) internal {
    RewardsManager.Epoch memory epoch = _epoch(epochId);
    vm.warp(epoch.endTimestamp - 1);
  }

  function _warpToAfterEpochEnd(uint256 epochId) internal {
    RewardsManager.Epoch memory epoch = _epoch(epochId);
    vm.warp(epoch.endTimestamp + 1);
  }

  function _fundRewardToken(address token, uint256 epochId, uint256 amount) internal {
    MintableERC20(token).mint(sponsor, amount);
    vm.startPrank(sponsor);
    MintableERC20(token).approve(address(rewardsManager), amount);
    rewardsManager.addReward(epochId, address(vault), token, amount);
    vm.stopPrank();
  }

  ///////////////////////////// TESTS /////////////////////////////

  function test_deploy_initialState() external view {
    assertEq(rewardsManager.DEPLOY_TIME(), 1_700_000_000);
    assertEq(rewardsManager.currentEpoch(), 1);

    RewardsManager.Epoch memory epoch = rewardsManager.getEpochData(1);
    assertEq(epoch.startTimestamp, rewardsManager.DEPLOY_TIME());
    assertEq(epoch.endTimestamp, rewardsManager.DEPLOY_TIME() + rewardsManager.SECONDS_PER_EPOCH());
  }

  function test_sponsor_addReward_futureEpoch_updatesMapping() external {
    uint256 epochNow = rewardsManager.currentEpoch();
    uint256 epochId = epochNow + 1; // ?? 

    uint256 amount = 1_000e18;
    rewardToken.mint(sponsor, amount);

    vm.startPrank(sponsor);
    rewardToken.approve(address(rewardsManager), amount);
    rewardsManager.addReward(epochId, address(vault), address(rewardToken), amount);
    vm.stopPrank();

    assertEq(rewardsManager.rewards(epochId, address(vault), address(rewardToken)), amount);
  }

  function test_deposit_notifyTransfer_updatesSharesAndSupply() external {
    uint256 epochId = rewardsManager.currentEpoch();

    uint256 sharesMinted = 100e18;
    vm.prank(alice);
    vault.mintShares(alice, sharesMinted);

    assertEq(rewardsManager.shares(epochId, address(vault), alice), sharesMinted);
    assertEq(rewardsManager.totalSupply(epochId, address(vault)), sharesMinted);
  }

  function test_withdraw_notifyTransfer_updatesSharesAndSupply() external {
    uint256 epochId = rewardsManager.currentEpoch();

    vm.startPrank(alice);
    uint256 sharesMinted = 100e18;
    vault.mintShares(alice, sharesMinted);

    uint256 sharesBurnt = 50e18;
    vault.burnShares(alice, sharesBurnt);
    vm.stopPrank();

    assertEq(rewardsManager.shares(epochId, address(vault), alice), sharesMinted - sharesBurnt);
    assertEq(rewardsManager.totalSupply(epochId, address(vault)), sharesMinted - sharesBurnt);
  }

  function test_transfer_notifyTransfer_updatesSharesAndSupply() external {
    uint256 epochId = rewardsManager.currentEpoch();

    uint256 sharesMinted = 100e18;
    vm.startPrank(alice);
    vault.mintShares(alice, sharesMinted);

    uint256 sharesTransferred = 50e18;
    vault.transferShares(alice, bob, sharesTransferred);
    vm.stopPrank();

    assertEq(rewardsManager.shares(epochId, address(vault), alice), sharesMinted - sharesTransferred);
    assertEq(rewardsManager.shares(epochId, address(vault), bob), sharesTransferred);
    assertEq(rewardsManager.totalSupply(epochId, address(vault)), sharesMinted);
  }

  function test_accrueUserAndVault_accumulatesPoints() external {
    uint256 epochId = rewardsManager.currentEpoch();
    RewardsManager.Epoch memory epoch = _epoch(epochId);

    // deposit at start+100 
    _warpToEpochStartPlus100(epochId);
    vm.prank(alice);
    vault.mintShares(alice, 10e18);
    
    // warp forward 1,000 seconds and accrue explicitly
    vm.warp(epoch.startTimestamp + 1_100);
    rewardsManager.accrueUser(epochId, address(vault), alice);
    rewardsManager.accrueVault(epochId, address(vault));

    // expected: alice held 10e18 for (1100 - 100) = 1000 seconds since her last accrue timestamp
    uint256 expectedUserPoints = 10e18 * 1_000;
    assertEq(rewardsManager.points(epochId, address(vault), alice), expectedUserPoints);

    // expected: vault held 10e18 for 1,000 seconds since its last accrue timestamp
    uint256 expectedVaultPoints = 10e18 * 1_000;
    assertEq(rewardsManager.totalPoints(epochId, address(vault)), expectedVaultPoints);
  }

  function test_claimReward_paysAndPreventsDoubleClaim() external {
    uint256 epochId = rewardsManager.currentEpoch();
    RewardsManager.Epoch memory epoch = _epoch(epochId);

    // fund rewards token for this epoch
    _fundRewardToken(address(rewardToken), epochId, 1_000e18);
    
    _warpToEpochStartPlus100(epochId);
    vm.prank(alice);
    vault.mintShares(alice, 10e18);

    _warpToEpochStartPlus200(epochId);
    vm.prank(bob);
    vault.mintShares(bob, 30e18);

    // move to the next epoch
    _warpToAfterEpochEnd(epochId);

    // claim for alice and bob
    uint256 aliceBalBefore = rewardToken.balanceOf(alice);
    uint256 bobBalBefore = rewardToken.balanceOf(bob);

    rewardsManager.claimReward(epochId, address(vault), address(rewardToken), alice);
    rewardsManager.claimReward(epochId, address(vault), address(rewardToken), bob);

    uint256 alicePaid = rewardToken.balanceOf(alice) - aliceBalBefore;
    uint256 bobPaid = rewardToken.balanceOf(bob) - bobBalBefore;

    // expected pro rata by time-weighted points
    // alice = 10e18 * (end - (start+100))
    // bob = 30e18 * (end - (start+200))
    uint256 alicePts = 10e18 * (epoch.endTimestamp - (epoch.startTimestamp + 100));
    uint256 bobPts = 30e18 * (epoch.endTimestamp - (epoch.startTimestamp + 200));
    uint256 totPts = alicePts + bobPts;

    assertEq(alicePaid, (1_000e18 * alicePts) / totPts);
    assertEq(bobPaid, (1_000e18 * bobPts) / totPts);

    // double-claim should revert
    vm.expectRevert(bytes("already claimed"));
    rewardsManager.claimReward(epochId, address(vault), address(rewardToken), alice);
  }

  function test_anyoneCanClaimForOthers() external {
    uint256 epochId = rewardsManager.currentEpoch();
    RewardsManager.Epoch memory epoch = _epoch(epochId);

    _fundRewardToken(address(rewardToken), epochId, 100e18);

    _warpToEpochStartPlus1(epochId);
    vault.mintShares(alice, 100e18);

    _warpToAfterEpochEnd(epochId);

    address relayer = address(0xAB3F3F);
    vm.prank(relayer);
    rewardsManager.claimReward(epochId, address(vault), address(rewardToken), alice);

    assertGt(rewardToken.balanceOf(alice), 0);
  }

}