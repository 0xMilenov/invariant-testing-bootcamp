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
    MockVault mockVault;
    RewardsManager rewardsManager;
    
    /// === Setup === ///
    /// This contains all calls to be performed in the tester constructor, both for Echidna and Foundry
    function setup() internal virtual override {
        rewardsManager = new RewardsManager(); // TODO: Add parameters here
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
