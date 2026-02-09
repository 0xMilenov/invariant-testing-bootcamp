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

    MockERC20 internal asset;
    MockERC4626 internal vault;

    address internal alice;
    address internal bob;

    uint256 internal initialTrackedAssetSum;

    int256 maxPriceDifferenceIncrease;
    int256 maxPriceDifferenceDecrease;

    /// === Setup === ///
    function setup() internal virtual override {
        asset = new MockERC20("Asset", "AST", 18);
        vault = new MockERC4626(asset, "Vault Share", "vAST");

        alice = address(0xA11CE);
        bob = address(0xB0B);

        _addActor(alice);
        _addActor(bob);

        _switchActor(1);

        address[] memory approvalArray = new address[](1);
        approvalArray[0] = address(vault);

        // from asset manager - mint tokens and set approvals
        _finalizeAssetDeployment(_getActors(), approvalArray, type(uint88).max);

        initialTrackedAssetSum = asset.balanceOf(alice) + asset.balanceOf(bob) + asset.balanceOf(address(vault));
    }
}
