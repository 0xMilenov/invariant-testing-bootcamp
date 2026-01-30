// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";
import {BeforeAfter} from "./BeforeAfter.sol";

abstract contract Properties is BeforeAfter, Asserts {
    function invariant_totalAssets_matches_assetBalance() public {
        eq(vault.totalAssets(), asset.balanceOf(address(vault)), "totalAssets does not match assetBalance");
    }

    function invariant_totalSupply_equals_sumBalances() public {
        eq(vault.totalSupply(), vault.balanceOf(alice) + vault.balanceOf(bob), "totalSupple does not equal sum of balances");
    }

    function invariant_limits_consistency() public {
        eq(vault.maxRedeem(alice), vault.balanceOf(alice), "maxRedeem(alice) wrong");
        eq(vault.maxRedeem(bob), vault.balanceOf(bob), "maxRedeem(bob) wrong");

        eq(vault.maxWithdraw(alice), vault.convertToAssets(vault.balanceOf(alice)), "maxWithdraw(alice) wrong");
        eq(vault.maxWithdraw(bob), vault.convertToAssets(vault.balanceOf(bob)), "maxWithdraw(bob) wrong");
    }

    function invariant_asset_conversation_trackedActors() public {
        uint256 currentSum = asset.balanceOf(alice) + asset.balanceOf(bob) + asset.balanceOf(address(vault));
        eq(currentSum, initialTrackedAssetSum, "tracked asset sum changed");
    }
}
