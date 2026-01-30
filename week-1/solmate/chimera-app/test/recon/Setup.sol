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
import {MockERC20} from "src/mocks/MockERC20.sol";
import {MockERC4626} from "src/mocks/MockERC4626.sol";

abstract contract Setup is BaseSetup, ActorManager, AssetManager, Utils {

    MockERC20 asset;
    MockERC4626 vault;

    address internal alice;
    address internal bob;

    uint256 internal initialTrackedAssetSum;

    /// === Setup === ///
    /// This contains all calls to be performed in the tester constructor, both for Echidna and Foundry
    function setup() internal virtual override {

        alice = address(0xA11CE);
        bob = address(0xB0B);

        _addActor(alice);
        _addActor(bob);
        
        _switchActor(1);

        asset = new MockERC20("Asset", "AST", 18);
        vault = new MockERC4626(asset, "Vault Share", "vAST");

        asset.mint(alice, 1_000_000e18);
        asset.mint(bob, 1_000_000e18);

        // will this work for echidna?
        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        asset.approve(address(vault), type(uint256).max);

        initialTrackedAssetSum = asset.balanceOf(alice) + asset.balanceOf(bob) + asset.balanceOf(address(vault));
    }

    /// === MODIFIERS === ///
    /// Prank admin and actor
    
    modifier asAdmin {
        vm.prank(address(this));
        _;
    }

    modifier asActor {
        vm.startPrank(_getActor());
        _;
        vm.stopPrank();
    }
}
