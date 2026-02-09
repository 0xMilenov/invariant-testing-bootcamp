// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";
import {MockERC20} from "@recon/MockERC20.sol";

import {MockVault} from "../Setup.sol";

import "src/RewardsManager.sol";

abstract contract RewardsManagerTargets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///

    // acrue user clamped
    function rewardsManager_accrueUser_clamped(uint256 epochId, uint8 vaultIndex, uint8 userEntropy) public {
        uint256 currentEpochId = rewardsManager.currentEpoch();
        if (currentEpochId == 0) currentEpochId = 1;
        epochId = (epochId % currentEpochId) + 1;

        address vault = address(_getDeployedVault(vaultIndex));

        address[] memory actors = _getActors();
        address user = actors[userEntropy % actors.length];

        rewardsManager_accrueUser(epochId, vault, user);
    }

    // accrue vault clamped
    function rewardsManager_accrueVault_clamped(uint256 epochId, uint8 vaultIndex) public {
        uint256 currentEpochId = rewardsManager.currentEpoch();
        if (currentEpochId == 0) currentEpochId = 1;
        epochId = (epochId % currentEpochId) + 1;

        address vault = address(_getDeployedVault(vaultIndex));

        rewardsManager_accrueVault(epochId, vault);
    }

    // add reward clamped
    function rewardsManager_addReward_clamped(uint256 epochId, uint8 vaultIndex, uint256 amount) public {
        uint256 currentEpochId = rewardsManager.currentEpoch();
        epochId = currentEpochId + (epochId % 10); // up to 10 epochs

        address vault = address(_getDeployedVault(vaultIndex));

        address token = _getAsset();

        uint256 actorBalance = MockERC20(token).balanceOf(_getActor());
        if (actorBalance > 0) {
            amount = amount % (actorBalance + 1);
        } else {
            amount = 0;
        }

        // double check
        vm.prank(_getActor());
        MockERC20(token).approve(address(rewardsManager), amount);

        rewardsManager_addReward(epochId, vault, token, amount);
    }

    // claim reward clamped
    function rewardsManager_claimReward_clamped(uint256 epochId, uint8 vaultIndex, uint8 userEntropy) public {
        uint256 currentEpochId = rewardsManager.currentEpoch();
        if (currentEpochId <= 1) return;
        
        epochId = (epochId % (currentEpochId - 1)) + 1;
        
        address vault = address(_getDeployedVault(vaultIndex));
        
        address token = _getAsset();
        
        address[] memory actors = _getActors();
        address user = actors[userEntropy % actors.length];
        
        rewardsManager_claimReward(epochId, vault, token, user);
    }

    // deposit clamped
    function mockVault_deposit_clamped(uint256 amount, uint8 vaultIndex, uint8 userEntropy) public {
        MockVault vault = _getDeployedVault(vaultIndex);
        
        address[] memory actors = _getActors();
        address user = actors[userEntropy % actors.length];
        
        amount = amount % (type(uint128).max + 1);
        
        vault.deposit(user, amount);
    }

    // withdraw clamped
     function mockVault_withdraw_clamped(uint256 amount, uint8 vaultIndex, uint8 userEntropy) public {
        MockVault vault = _getDeployedVault(vaultIndex);
        
        address[] memory actors = _getActors();
        address user = actors[userEntropy % actors.length];
        
        uint256 currentEpochId = rewardsManager.currentEpoch();
        uint256 userShares = rewardsManager.shares(currentEpochId, address(vault), user);
        
        if (userShares > 0) {
            amount = amount % (userShares + 1);
        } else {
            amount = 0;
        }
        
        vault.withdraw(user, amount);
    }

    // transfer clamped
    function mockVault_transfer_clamped(uint256 amount, uint8 vaultIndex, uint8 fromEntropy, uint8 toEntropy) public {
        MockVault vault = _getDeployedVault(vaultIndex);
        
        address[] memory actors = _getActors();
        address from = actors[fromEntropy % actors.length];
        address to = actors[toEntropy % actors.length];
        
        if (from == to) return;
        
        uint256 currentEpochId = rewardsManager.currentEpoch();
        uint256 fromShares = rewardsManager.shares(currentEpochId, address(vault), from);
        
        if (fromShares > 0) {
            amount = amount % (fromShares + 1);
        } else {
            amount = 0;
        }
        
        vault.transfer(from, to, amount);
    }

    function rewardsManager_reap_clamped() public {
        rewardsManager_reap(_getOptimizedClaimParams());
    }

    function rewardsManager_tear_clamped() public {
        rewardsManager_tear(_getOptimizedClaimParams());
    }


    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function rewardsManager_accrueUser(uint256 epochId, address vault, address user) public asActor {
        rewardsManager.accrueUser(epochId, vault, user);
    }

    function rewardsManager_accrueVault(uint256 epochId, address vault) public asActor {
        rewardsManager.accrueVault(epochId, vault);
    }

    function rewardsManager_addBulkRewards(uint256 epochStart, uint256 epochEnd, address vault, address token, uint256[] memory amounts) public asActor {
        rewardsManager.addBulkRewards(epochStart, epochEnd, vault, token, amounts);
    }

    function rewardsManager_addBulkRewardsLinearly(uint256 epochStart, uint256 epochEnd, address vault, address token, uint256 total) public asActor {
        rewardsManager.addBulkRewardsLinearly(epochStart, epochEnd, vault, token, total);
    }

    function rewardsManager_addReward(uint256 epochId, address vault, address token, uint256 amount) public asActor {
        rewardsManager.addReward(epochId, vault, token, amount);
    }

    function rewardsManager_claimBulkTokensOverMultipleEpochs(uint256 epochStart, uint256 epochEnd, address vault, address[] memory tokens, address user) public asActor {
        rewardsManager.claimBulkTokensOverMultipleEpochs(epochStart, epochEnd, vault, tokens, user);
    }

    function rewardsManager_claimReward(uint256 epochId, address vault, address token, address user) public asActor {
        rewardsManager.claimReward(epochId, vault, token, user);
    }

    function rewardsManager_claimRewardEmitting(uint256 epochId, address vault, address token, address user) public asActor {
        rewardsManager.claimRewardEmitting(epochId, vault, token, user);
    }

    function rewardsManager_claimRewardReferenceEmitting(uint256 epochId, address vault, address token, address user) public asActor {
        rewardsManager.claimRewardReferenceEmitting(epochId, vault, token, user);
    }

    function rewardsManager_claimRewards(uint256[] memory epochsToClaim, address[] memory vaults, address[] memory tokens, address[] memory users) public asActor {
        rewardsManager.claimRewards(epochsToClaim, vaults, tokens, users);
    }

    function rewardsManager_notifyTransfer(address from, address to, uint256 amount) public asActor {
        rewardsManager.notifyTransfer(from, to, amount);
    }

    function rewardsManager_reap(RewardsManager.OptimizedClaimParams memory params) public asActor {
        rewardsManager.reap(params);
    }

    function rewardsManager_tear(RewardsManager.OptimizedClaimParams memory params) public asActor {
        rewardsManager.tear(params);
    }
}