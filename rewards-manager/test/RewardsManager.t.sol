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

  function test_addReward_revertsIfVaultZero() external {
    uint256 epochId = rewardsManager.currentEpoch();
    uint256 amount = 100e18;

    vm.startPrank(sponsor);
    rewardToken.mint(sponsor, amount);
    rewardToken.approve(address(rewardsManager), amount);

    vm.expectRevert(bytes("youtu.be/F3L376eH09Q"));
    rewardsManager.addReward(epochId, address(0), address(rewardToken), amount);
    vm.stopPrank();
  }

  function test_addReward_feeOnTransfer_creditsByBalanceDelta() external {
    uint256 epochId = rewardsManager.currentEpoch() + 1;
    uint256 amount = 100e18;

    vm.startPrank(sponsor);
    fotRewardToken.mint(sponsor, amount);
    fotRewardToken.approve(address(rewardsManager), amount);
    rewardsManager.addReward(epochId, address(vault), address(fotRewardToken), amount);
    vm.stopPrank();

    uint256 credited = rewardsManager.rewards(epochId, address(vault), address(fotRewardToken));
    assertGt(credited, 0);
    assertLt(credited, amount); // because of the fee
  }

  function test_notifyTransfer_revertsIfFromEqualsTo() external {
    vm.prank(address(vault));
    vm.expectRevert(bytes("Cannot transfer to yourself"));
    rewardsManager.notifyTransfer(alice, alice, 1);
  }

  function test_futureEpoch_guards() external {
    uint256 futureEpoch = rewardsManager.currentEpoch() + 1;

    vm.expectRevert(bytes("Cannot see the future"));
    rewardsManager.accrueVault(futureEpoch, address(vault));

    vm.expectRevert(bytes("Cannot see the future"));
    rewardsManager.getVaultTimeLeftToAccrue(futureEpoch, address(vault));

    vm.expectRevert(bytes("Cannot see the future"));
    rewardsManager.getTotalSupplyAtEpoch(futureEpoch, address(vault));

    vm.expectRevert(bytes("Cannot see the future"));
    rewardsManager.getBalanceAtEpoch(futureEpoch, address(vault), alice);

    vm.expectRevert(bytes("only ended epochs"));
    rewardsManager.accrueUser(futureEpoch, address(vault), alice);
  }

  function test_addBulkRewardsLinearly_mustDivideEvenly() external {
    uint256 start = rewardsManager.currentEpoch() + 1;
    uint256 end = start + 2; // epoch 3
    uint256 total = 100e18; // not divisible by 3

    vm.startPrank(sponsor);
    rewardToken.mint(sponsor, total);
    rewardToken.approve(address(rewardsManager), total);

    vm.expectRevert(bytes("must divide evenly"));
    rewardsManager.addBulkRewardsLinearly(start, end, address(vault), address(rewardToken), total);
    vm.stopPrank();
  }

  function test_addBulkRewardsLinearly_noFeeOOnTransfer() external {
     uint256 start = rewardsManager.currentEpoch() + 1;
    uint256 end = start; // epoch 1
    uint256 total = 100e18;

    vm.startPrank(sponsor);
    fotRewardToken.mint(sponsor, total);
    fotRewardToken.approve(address(rewardsManager), total);

    vm.expectRevert(bytes("no feeOnTransfer"));
    rewardsManager.addBulkRewardsLinearly(start, end, address(vault), address(fotRewardToken), total);
    vm.stopPrank();
  }

  function test_addBulkRewards_lengthMismatch() external {
    uint256 start = rewardsManager.currentEpoch() + 1;
    uint256 end = start + 1; // 2 epochs

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 1e18;

    vm.startPrank(sponsor);
    rewardToken.mint(sponsor, 1e18);
    rewardToken.approve(address(rewardsManager), 1e18);

    vm.expectRevert(bytes("length mismatch"));
    rewardsManager.addBulkRewards(start, end, address(vault), address(rewardToken), amounts);
    vm.stopPrank();
  }

  function test_claimRewards_lengthMismatch_reverts() external {
    uint256[] memory epochs = new uint256[](1);
    address[] memory vaults = new address[](2);
    address[] memory tokens = new address[](1);
    address[] memory users = new address[](1);

    epochs[0] = 1;
    vaults[0] = address(vault);
    vaults[1] = address(vault);
    tokens[0] = address(rewardToken);
    users[0] = alice;

    vm.expectRevert(bytes("length mismatch"));
    rewardsManager.claimRewards(epochs, vaults, tokens, users);
  }

  function test_claimRewardsEmitting_worksWhenRewardsManagerHasShares() external {
    uint256 epochId = rewardsManager.currentEpoch();

    _fundRewardToken(address(rewardToken), epochId, 100e18);

    _warpToEpochStartPlus1(epochId);
    vault.mintShares(address(rewardsManager), 100e18);
    vault.mintShares(alice, 10e18);

    _warpToAfterEpochEnd(epochId);

    uint256 before = rewardToken.balanceOf(alice);
    rewardsManager.claimRewardEmitting(epochId, address(vault), address(rewardToken), alice);
    assertGt(rewardToken.balanceOf(alice) - before, 0);

    vm.expectRevert(bytes("already claimed"));
    rewardsManager.claimRewardEmitting(epochId, address(vault), address(rewardToken), alice);
  }

  function test_addBulkRewardsLinearly_success_splitsEvenly() external {
    uint256 start = rewardsManager.currentEpoch() + 1;
    uint256 end = start + 2; // epoch 3
    uint256 total = 300e18; // divisible by 3
    uint256 perEpoch = total / 3;

    vm.startPrank(sponsor);
    rewardToken.mint(sponsor, total);
    rewardToken.approve(address(rewardsManager), total);

    rewardsManager.addBulkRewardsLinearly(start, end, address(vault), address(rewardToken), total);
    vm.stopPrank();

    assertEq(rewardsManager.rewards(start, address(vault), address(rewardToken)), perEpoch);
    assertEq(rewardsManager.rewards(start + 1, address(vault), address(rewardToken)), perEpoch);
    assertEq(rewardsManager.rewards(start + 2, address(vault), address(rewardToken)), perEpoch);
  }

  function test_addBulkRewards_success_customAmounts() external {
    uint256 start = rewardsManager.currentEpoch() + 1;
    uint256 end = start + 1; // epoch 2

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = 100e18;
    amounts[1] = 200e18;

    uint256 total = amounts[0] + amounts[1];

    vm.startPrank(sponsor);
    rewardToken.mint(sponsor, total);
    rewardToken.approve(address(rewardsManager), total);

    rewardsManager.addBulkRewards(start, end, address(vault), address(rewardToken), amounts);
    vm.stopPrank();

    assertEq(rewardsManager.rewards(start, address(vault), address(rewardToken)), amounts[0]);
    assertEq(rewardsManager.rewards(start + 1, address(vault), address(rewardToken)), amounts[1]);
  }

  function test_getUserTimeLeftToAccrue_branches() external {
    uint256 epochId = rewardsManager.currentEpoch();
    RewardsManager.Epoch memory epoch = _epoch(epochId);

    // user has shares in this epoch
    _warpToEpochStartPlus1(epochId);
    vault.mintShares(alice, 10e18);

    // lastUserAccrueTimestamp == 0
    _warpToEpochStartPlus100(epochId);
    uint256 t1 = rewardsManager.getUserTimeLeftToAccrue(epochId, address(vault), alice);
    assertEq(t1, 100 - 1);

    // force an accrue after epoch end so lastUserAccrueTimestamp >= epoch.endTimestamp
    _warpToAfterEpochEnd(epochId);
    rewardsManager.accrueUser(epochId, address(vault), alice);

    // querying in same timestamp = 0
    uint256 t2 = rewardsManager.getUserTimeLeftToAccrue(epochId, address(vault), alice);
    assertEq(t2, 0);
  }

  function test_getVaultTimeLeftToAccrue_branches() external {
    uint256 epochId = rewardsManager.currentEpoch();
    RewardsManager.Epoch memory epoch = _epoch(epochId);

    _warpToEpochStartPlus1(epochId);
    vault.mintShares(address(vault), 20e18);

    // lastVaultAccrueTimestamp == 0
    _warpToEpochStartPlus100(epochId);
    uint256 t1 = rewardsManager.getVaultTimeLeftToAccrue(epochId, address(vault));
    assertEq(t1, 100 - 1);

    _warpToAfterEpochEnd(epochId);
    rewardsManager.accrueVault(epochId, address(vault));

    uint256 t2 = rewardsManager.getVaultTimeLeftToAccrue(epochId, address(vault));
    assertEq(t2, 0);
  }

  function test_getTotalSupplyAtEpoch_lookback_shouldUpdateTrue() external {
    uint256 epoch1 = rewardsManager.currentEpoch();
    RewardsManager.Epoch memory e1 = _epoch(epoch1);

    _warpToEpochStartPlus1(epoch1);
    vault.mintShares(alice, 20e18);

    _warpToEpochStartPlus100(epoch1);
    rewardsManager.accrueVault(epoch1, address(vault));

    _warpToAfterEpochEnd(epoch1);
    uint256 epoch2 = rewardsManager.currentEpoch();

    (uint256 supply2, bool shouldUpdate2) = rewardsManager.getTotalSupplyAtEpoch(epoch2, address(vault));
    assertEq(supply2, 20e18);
    assertEq(shouldUpdate2, true);
  }

  function test_getTotalSupplyAtEpoch_lookback_lastKnownZero_returnsNoUpdate() external {
    uint256 epoch1 = rewardsManager.currentEpoch();
    RewardsManager.Epoch memory e1 = _epoch(epoch1);

    _warpToEpochStartPlus1(epoch1);
    vault.mintShares(alice, 5e18);

    vm.warp(e1.startTimestamp + 10);
    vault.burnShares(alice, 5e18);

    vm.warp(e1.startTimestamp + 20);
    rewardsManager.accrueVault(epoch1, address(vault));

    _warpToAfterEpochEnd(epoch1);
    uint256 epoch2 = rewardsManager.currentEpoch();

    (uint256 supply2, bool shouldUpdate2) = rewardsManager.getTotalSupplyAtEpoch(epoch2, address(vault));
    assertEq(supply2, 0);
    assertEq(shouldUpdate2, false);
  }

  function test_claimRewardReferenceEmitting_paysThenReturnsOnSecondCall() external {
    uint256 epochId = rewardsManager.currentEpoch();

    _fundRewardToken(address(rewardToken), epochId, 100e18);

    _warpToEpochStartPlus1(epochId);
    vault.mintShares(alice, 1e18);

    _warpToAfterEpochEnd(epochId);

    uint256 before = rewardToken.balanceOf(alice);
    rewardsManager.claimRewardReferenceEmitting(epochId, address(vault), address(rewardToken), alice);
    uint256 paid1 = rewardToken.balanceOf(alice) - before;
    assertGt(paid1, 0);

    uint256 before2 = rewardToken.balanceOf(alice);
    rewardsManager.claimRewardReferenceEmitting(epochId, address(vault), address(rewardToken), alice);
    uint256 paid2 = rewardToken.balanceOf(alice) - before2;
    assertEq(paid2, 0);
  }

  function test_claimRewards_success_loop() external {
    uint256 epochId = rewardsManager.currentEpoch();

    _fundRewardToken(address(rewardToken), epochId, 100e18);

    _warpToEpochStartPlus1(epochId);
    vault.mintShares(alice, 1e18);

    _warpToAfterEpochEnd(epochId);

    uint256[] memory epochs = new uint256[](1);
    address[] memory vaults = new address[](1);
    address[] memory tokens = new address[](1);
    address[] memory users = new address[](1);

    epochs[0] = epochId;
    vaults[0] = address(vault);
    tokens[0] = address(rewardToken);
    users[0] = alice;

    rewardsManager.claimRewards(epochs, vaults, tokens, users);
    assertGt(rewardToken.balanceOf(alice), 0);
  }

  function test_claimBulkTokensOverMultipleEpochs_success_and_dupRevert() external {
    uint256 epoch1 = rewardsManager.currentEpoch();

    _fundRewardToken(address(rewardToken), epoch1, 50e18);

    _warpToEpochStartPlus1(epoch1);
    vault.mintShares(alice, 2e18);

    _warpToAfterEpochEnd(epoch1);
    uint256 epoch2 = rewardsManager.currentEpoch();
    _fundRewardToken(address(rewardToken), epoch2, 25e18);

    _warpToEpochStartPlus1(epoch2);
    vault.mintShares(alice, 1e18);

    _warpToAfterEpochEnd(epoch2);

    address[] memory tokens = new address[](1);
    tokens[0] = address(rewardToken);

    uint256 before = rewardToken.balanceOf(alice);
    rewardsManager.claimBulkTokensOverMultipleEpochs(epoch1, epoch2, address(vault), tokens, alice);
    uint256 paid = rewardToken.balanceOf(alice) - before;
    assertGt(paid, 0);

    address[] memory dupTokens = new address[](2);
    dupTokens[0] = address(rewardToken);
    dupTokens[1] = address(rewardToken);

    vm.expectRevert(bytes("dup"));
    rewardsManager.claimBulkTokensOverMultipleEpochs(epoch1, epoch2, address(vault), dupTokens, alice);
  }
}