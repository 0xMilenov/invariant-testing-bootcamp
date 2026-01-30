// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {BaseSetup} from "@chimera/BaseSetup.sol";

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

    /// === Setup === ///
    function setup() internal virtual override {
        asset = new MockERC20("Asset", "AST", 18);
        vault = new MockERC4626(asset, "Vault Share", "vAST");

        alice = address(new Actor(asset, vault));
        bob = address(new Actor(asset, vault));

        _addActor(alice);
        _addActor(bob);

        _switchActor(1);

        asset.mint(alice, 1_000_000e18);
        asset.mint(bob, 1_000_000e18);

        initialTrackedAssetSum = asset.balanceOf(alice) + asset.balanceOf(bob) + asset.balanceOf(address(vault));
    }
}

contract Actor {
    MockERC20 internal asset;
    MockERC4626 internal vault;

    constructor(MockERC20 _asset, MockERC4626 _vault) {
        asset = _asset;
        vault = _vault;
        asset.approve(address(vault), type(uint256).max);
    }

    function deposit(uint256 assetsIn) external {
        vault.deposit(assetsIn, address(this));
    }

    function mint(uint256 sharesOut) external {
        vault.mint(sharesOut, address(this));
    }

    function withdraw(uint256 assetsOut) external {
        vault.withdraw(assetsOut, address(this), address(this));
    }

    function redeem(uint256 sharesIn) external {
        vault.redeem(sharesIn, address(this), address(this));
    }
}
