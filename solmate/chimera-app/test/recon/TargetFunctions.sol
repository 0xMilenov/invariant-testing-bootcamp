// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Targets
import {Properties} from "./Properties.sol";

import {vm} from "@chimera/Hevm.sol";

abstract contract TargetFunctions is Properties {
    function _trackedActor(uint256 entropy) internal view returns (address) {
        return (entropy % 2 == 0) ? alice : bob;
    }

    function switchActor(uint256 entropy) public {
        _switchActor((entropy % 2) + 1); // 1 => alice, 2 => bob
    }

    function vault_deposit(uint256 assetsIn, uint256 receiverEntropy) public updateGhosts {
        address caller = _getActor();
        address receiver = _trackedActor(receiverEntropy);

        uint256 bal = asset.balanceOf(caller);
        assetsIn = between(assetsIn, 0, bal);

        if (assetsIn == 0) return;
        if (vault.previewDeposit(assetsIn) == 0) return;

        vm.prank(caller);
        vault.deposit(assetsIn, receiver);
    }

    function vault_mint(uint256 sharesOut, uint256 receiverEntropy) public updateGhosts {
        address caller = _getActor();
        address receiver = _trackedActor(receiverEntropy);

        sharesOut = between(sharesOut, 0, 1_000_000e18);

        if (sharesOut == 0) return;

        uint256 assetsIn = vault.previewMint(sharesOut);
        if (assetsIn == 0) return;

        if (assetsIn > asset.balanceOf(caller)) return;

        vm.prank(caller);
        vault.mint(sharesOut, receiver);
    }

    function vault_withdraw(uint256 assetsOut, uint256 receiverEntropy, uint256 ownerEntropy) public updateGhosts {
        address caller = _getActor();
        address receiver = _trackedActor(receiverEntropy);
        address owner = _trackedActor(ownerEntropy);

        uint256 maxAssets = vault.maxWithdraw(owner);
        if (maxAssets == 0) return;

        assetsOut = between(assetsOut, 0, maxAssets);
        if (assetsOut == 0) return;

        vm.prank(caller);
        vault.withdraw(assetsOut, receiver, owner);
    }

    function vault_redeem(uint256 shares, uint256 receiverEntropy, uint256 ownerEntropy) public updateGhosts {
        address caller = _getActor();
        address receiver = _trackedActor(receiverEntropy);
        address owner = _trackedActor(ownerEntropy);

        uint256 maxShares = vault.maxRedeem(owner);
        if (maxShares == 0) return;

        shares = between(shares, 0, maxShares);
        if (shares == 0) return;

        if (vault.previewRedeem(shares) == 0) return;

        vm.prank(caller);
        vault.redeem(shares, receiver, owner);
    }

    function vault_views(uint256 assets, uint256 shares, uint256 whoEntropy) public {
        address who = _trackedActor(whoEntropy);

        vault.totalAssets();
        vault.convertToShares(assets);
        vault.convertToAssets(shares);

        vault.previewDeposit(assets);
        vault.previewMint(shares);
        vault.previewWithdraw(assets);
        vault.previewRedeem(shares);

        vault.maxDeposit(who);
        vault.maxMint(who);
        vault.maxWithdraw(who);
        vault.maxRedeem(who);
    }

    function vault_approveShares(uint256 spenderEntropy, uint256 amount) public {
        address owner = _getActor();
        address spender = _trackedActor(spenderEntropy);
        if (spender == owner) return;

        amount = between(amount, 0, 1_000_000e18);

        vm.prank(owner);
        vault.approve(spender, amount);
    }

}
