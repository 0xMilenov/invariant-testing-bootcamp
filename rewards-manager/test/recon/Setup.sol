// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {BaseSetup} from "@chimera/BaseSetup.sol";
import {vm} from "@chimera/Hevm.sol";

// Managers
import {ActorManager} from "@recon/ActorManager.sol";
import {AssetManager} from "@recon/AssetManager.sol";

// Helpers
import {Utils} from "@recon/Utils.sol";

// Your deps
import "src/RewardsManager.sol";

/// @dev MockVault contract that wraps notifyTransfer calls so msg.sender is the vault address
/// @notice This simulates real vault integrations where vaults report balance changes
contract MockVault {
    RewardsManager public rewardsManager;

    constructor(RewardsManager _rewardsManager) {
        rewardsManager = _rewardsManager;
    }

    /// @dev Simulate a deposit - from is address(0), to is the user
    function deposit(address user, uint256 amount) external {
        rewardsManager.notifyTransfer(address(0), user, amount);
    }

    /// @dev Simulate a withdrawal - to is address(0), from is the user
    function withdraw(address user, uint256 amount) external {
        rewardsManager.notifyTransfer(user, address(0), amount);
    }

    /// @dev Simulate a transfer between users
    function transfer(address from, address to, uint256 amount) external {
        rewardsManager.notifyTransfer(from, to, amount);
    }
}

abstract contract Setup is BaseSetup, ActorManager, AssetManager, Utils {


    // constants 
    uint256 internal constant DECIMALS = 18;
    uint256 internal constant SECONDS_PER_EPOCH = 604800; // 1 week

    // main contract
    RewardsManager rewardsManager;
    
    // multiple vaults
    MockVault[] internal deployedVaults;

    // structs
    RewardsManager.OptimizedClaimParams internal optimizedClaimParams;
    
    /// === Setup === ///
    /// This contains all calls to be performed in the tester constructor, both for Echidna and Foundry
    function setup() internal virtual override {

        vm.warp(block.timestamp + 1);

        rewardsManager = new RewardsManager();

        _addActor(address(0xA11CE));

        _newAsset(uint8(DECIMALS));

        MockVault mockVault = new MockVault(rewardsManager);
        deployedVaults.push(mockVault);

        address[] memory emptyTokens = new address[](0);
        optimizedClaimParams = RewardsManager.OptimizedClaimParams({
            epochStart: 1,
            epochEnd: 1,
            vault: address(mockVault),
            tokens: emptyTokens
        });

        address[] memory approvalArray = new address[](1);
        approvalArray[0] = address(rewardsManager);

        // from asset manager - mint tokens and set approvals
        _finalizeAssetDeployment(_getActors(), approvalArray, type(uint88).max);
    }

    function helper_deployVault() public {
        MockVault newVault = new MockVault(rewardsManager);
        deployedVaults.push(newVault);
    }

    // time helper func
    function helper_warpToNextEpoch() public {
        vm.warp(block.timestamp + SECONDS_PER_EPOCH);
    }

    function helper_warpForward(uint256 secondsToWarp) public {
        uint256 maxWarp = SECONDS_PER_EPOCH * 10;
        uint256 boundedWarp = secondsToWarp % maxWarp;
        if (boundedWarp == 0) boundedWarp = 1;
        vm.warp(block.timestamp + boundedWarp);
    }

    // struct helper func
    function helper_updateClaimParams(uint256 epochStart, uint256 epochEnd, uint8 vaultIndex) public {
        if (epochEnd < epochStart) {
            epochEnd = epochStart;
        }

        uint256 current = rewardsManager.currentEpoch();
        if (epochStart < 1) epochStart = 1;
        if (epochEnd >= current) epochEnd = current > 1 ? current - 1 : 1;
        if (epochStart > epochEnd) epochStart = epochEnd;

        optimizedClaimParams.epochStart = epochStart;
        optimizedClaimParams.epochEnd = epochEnd;
        optimizedClaimParams.vault = address(_getDeployedVault(vaultIndex));
    }

    function helper_addTokenToClaimParams(address token) public {
        for (uint256 i = 0; i < optimizedClaimParams.tokens.length; i++) {
            if (optimizedClaimParams.tokens[i] == token) {
                return; // already exists
            }
        }

        address[] memory newTokens = new address[](optimizedClaimParams.tokens.length + 1);
        for (uint256 i = 0; i < optimizedClaimParams.tokens.length; i++) {
            newTokens[i] = optimizedClaimParams.tokens[i];
        }
        newTokens[optimizedClaimParams.tokens.length] = token;
        optimizedClaimParams.tokens = newTokens;
    }

    function helper_clearClaimParamsTokens() public {
        optimizedClaimParams.tokens = new address[](0);
    }

    // Get a vault from the deployedVaults array using modulo for safe indexing
    function _getDeployedVault(uint8 index) internal view returns (MockVault) {
        return deployedVaults[index % deployedVaults.length];
    }

    // vaults length 
    function _getDeployedVaultsLength() internal view returns (uint256) {
        return deployedVaults.length;
    }

    // get params 
    function _getOptimizedClaimParams() internal view returns (RewardsManager.OptimizedClaimParams memory) {
        return optimizedClaimParams;
    }

    /// === MODIFIERS === ///
    /// Prank admin and actor
    
    modifier asAdmin {
        vm.prank(address(this));
        _;
    }

    modifier asActor {
        vm.prank(address(_getActor()));
        _;
    }
}
