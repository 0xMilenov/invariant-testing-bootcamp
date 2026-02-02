// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";

import "forge-std/console2.sol";

import {Test} from "forge-std/Test.sol";
import {TargetFunctions} from "./TargetFunctions.sol";

import {Setup, MockVault as ReconMockVault} from "./Setup.sol";

// forge test --match-contract CryticToFoundry -vv
contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
        setup();

        targetContract(address(this));
    }

    // forge test --match-test test_crytic -vvv
    function test_crytic() public {
        // TODO: add failing property tests here for debugging
    }

    // accrue user
    function test_accrueUser() public {
        ReconMockVault vault = _getDeployedVault(0);
        address user = _getActor();


        vault.deposit(user, 1e18);

        uint256 epochId = rewardsManager.currentEpoch();

        rewardsManager_accrueUser(epochId, address(vault), user);
    }

    // accrue vault
    function test_accrueVault() public {
        ReconMockVault vault = _getDeployedVault(0);
        address user = _getActor();
        
        vault.deposit(user, 1e18);

        uint256 epochId = rewardsManager.currentEpoch();
        rewardsManager_accrueVault(epochId, address(vault));
    }

    // add rewards
    function test_addReward() public {
        ReconMockVault vault = _getDeployedVault(0);
        address token = _getAsset();
        uint256 epochId = rewardsManager.currentEpoch();
        uint256 amount = 1e18;

        rewardsManager_addReward(epochId, address(vault), token, amount);
    }

    // add bulk rewards
    function test_addBulkRewards() public {
        ReconMockVault vault = _getDeployedVault(0);
        address token = _getAsset();
        uint256 epochStart = rewardsManager.currentEpoch();
        uint256 epochEnd = epochStart + 2; // 3 epochs

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1e18;
        amounts[1] = 2e18;
        amounts[2] = 3e18;

        rewardsManager_addBulkRewards(epochStart, epochEnd, address(vault), token, amounts);
    }

    // add bulk rewards linearly
    function test_addBulkRewardsLinearly() public {
        ReconMockVault vault = _getDeployedVault(0);
        address token = _getAsset();
        uint256 epochStart = rewardsManager.currentEpoch();
        uint256 epochEnd = epochStart + 2; // 3 epochs
        uint256 total = 3e18; // divisible by 3

        rewardsManager_addBulkRewardsLinearly(epochStart, epochEnd, address(vault), token, total);
    }

    // notify transfer
    function test_notifyTransfer() public {
        ReconMockVault vault = _getDeployedVault(0);
        address user = _getActor();

        vault.deposit(user, 1e18);

        uint256 epochId = rewardsManager.currentEpoch();
        uint256 shares = rewardsManager.shares(epochId, address(vault), user);
        assertGt(shares, 0, "Shares should be recorded after deposit");
    }

    // claim reward
    function test_claimReward() public {
        ReconMockVault vault = _getDeployedVault(0);
        address token = _getAsset();
        address user = _getActor();
        
        uint256 depositAmount = 1e18;
        uint256 rewardAmount = 10e18;

        // deposit
        vault.deposit(user, depositAmount);

        // add rewards 
        uint256 epochId = rewardsManager.currentEpoch();
        rewardsManager_addReward(epochId, address(vault), token, rewardAmount);

        // warp to next epoch
        helper_warpToNextEpoch();

        // claim
        rewardsManager_claimReward(epochId, address(vault), token, user);
    }

    // claim reward emitting
    function test_claimRewardEmitting() public {
        ReconMockVault vault = _getDeployedVault(0);
        address token = _getAsset();
        address user = _getActor();
        uint256 depositAmount = 1e18;
        uint256 rewardAmount = 10e18;

        // deposit 
        vault.deposit(user, depositAmount);

        // add rewards
        uint256 epochId = rewardsManager.currentEpoch();
        rewardsManager_addReward(epochId, address(vault), token, rewardAmount);

        // warp to next epoch
        helper_warpToNextEpoch();

        // claim
        rewardsManager_claimRewardEmitting(epochId, address(vault), token, user);
    }

    // claim reward reference emitting
    function test_claimRewardReferenceEmitting() public {
        ReconMockVault vault = _getDeployedVault(0);
        address token = _getAsset();
        address user = _getActor();
        uint256 depositAmount = 1e18;
        uint256 rewardAmount = 10e18;

        // deposit 
        vault.deposit(user, depositAmount);

        // add rewards
        uint256 epochId = rewardsManager.currentEpoch();
        rewardsManager_addReward(epochId, address(vault), token, rewardAmount);

        // warp to next epoch
        helper_warpToNextEpoch();

        // claim
        rewardsManager_claimRewardReferenceEmitting(epochId, address(vault), token, user);
    }

    // claim rewards
    function test_claimRewards() public {
        ReconMockVault vault = _getDeployedVault(0);
        address token = _getAsset();
        address user = _getActor();
        
        uint256 depositAmount = 1e18;
        uint256 rewardAmount = 10e18;

        // deposit
        vault.deposit(user, depositAmount);

        // add rewards 
        uint256 epochId = rewardsManager.currentEpoch();
        rewardsManager_addReward(epochId, address(vault), token, rewardAmount);

        // warp to next epoch
        helper_warpToNextEpoch();

        // build the arrays
        uint256[] memory epochs = new uint256[](1);
        epochs[0] = epochId;

        address[] memory vaults = new address[](1);
        vaults[0] = address(vault);

        address[] memory tokens = new address[](1);
        tokens[0] = token;

        address[] memory users = new address[](1);
        users[0] = user;

        // claim rewards
        rewardsManager_claimRewards(epochs, vaults, tokens, users);
    }

    // claim rewards over multiple epochs
    function test_claimBulkTokensOverMultipleEpochs() public {
        ReconMockVault vault = _getDeployedVault(0);
        address token = _getAsset();
        address user = _getActor();
        uint256 depositAmount = 1e18;
        uint256 rewardAmount = 10e18;

        // deposit 
        uint256 epochStart = rewardsManager.currentEpoch();
        vault.deposit(user, depositAmount);

        // add rewards
        rewardsManager_addReward(epochStart, address(vault), token, rewardAmount);

        // warp to next epoch
        helper_warpToNextEpoch();
        uint256 epochEnd = rewardsManager.currentEpoch();
        rewardsManager_addReward(epochEnd, address(vault), token, rewardAmount);
        
        // warp again
        helper_warpToNextEpoch();

        // build the array which we need
        address[] memory tokens = new address[](1);
        tokens[0] = token;

        // claim bulk over multiple epochs
        rewardsManager_claimBulkTokensOverMultipleEpochs(epochStart, epochEnd, address(vault), tokens, user);
    }

    function test_reap() public {
        ReconMockVault vault = _getDeployedVault(0);
        address token = _getAsset();
        address user = _getActor();
        uint256 depositAmount = 1e18;
        uint256 rewardAmount = 10e18;

        // deposit
        uint256 epochStart = rewardsManager.currentEpoch();
        vault.deposit(user, depositAmount);

        // add rewards
        rewardsManager_addReward(epochStart, address(vault), token, rewardAmount);

        // warp to next epoch
        helper_warpToNextEpoch();

        // setup claim params using the helpers
        helper_updateClaimParams(epochStart, epochStart, 0);
        helper_addTokenToClaimParams(token);

        // call reap ( reap uses msg.sender as user, so we need to switch actor)
        switchActor(0);
        rewardsManager_reap(_getOptimizedClaimParams());
    }

    function test_tear() public {
        ReconMockVault vault = _getDeployedVault(0);
        address token = _getAsset();
        address user = _getActor();
        uint256 depositAmount = 1e18;
        uint256 rewardAmount = 10e18;

        // deposit
        uint256 epochStart = rewardsManager.currentEpoch();
        vault.deposit(user, depositAmount);

        // add rewards
        rewardsManager_addReward(epochStart, address(vault), token, rewardAmount);

        // warp to next epoch
        helper_warpToNextEpoch();

        // setup claim params using the helpers
        helper_updateClaimParams(epochStart, epochStart, 0);
        helper_addTokenToClaimParams(token);

        // call tear (tear uses msg.sender as user so we need to switch actor)
        switchActor(0);
        rewardsManager_tear(_getOptimizedClaimParams());
    }

}