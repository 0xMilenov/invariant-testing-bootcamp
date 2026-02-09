// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Setup} from "./Setup.sol";

// ghost variables for tracking state variable values before and after function calls
abstract contract BeforeAfter is Setup {
    struct Vars {
        uint256 vault_totalAssets;
        uint256 vault_totalSupply;
        uint256 vault_assetBalance;
        uint256 pricePerShare;

        uint256 alice_shares;
        uint256 bob_shares;

        uint256 trackedAssetSum;
    }

    Vars internal _before;
    Vars internal _after;

    modifier updateGhosts {
        __before();
        _;
        __after();
    }

    function __before() internal {
        _before.vault_totalAssets = vault.totalAssets();
        _before.vault_totalSupply = vault.totalSupply();
        _before.vault_assetBalance = asset.balanceOf(address(vault));

        _before.alice_shares = vault.balanceOf(alice);
        _before.bob_shares = vault.balanceOf(bob);

        _before.trackedAssetSum = asset.balanceOf(alice) + asset.balanceOf(bob) + asset.balanceOf(address(vault));

        _before.pricePerShare = vault.convertToShares(10 ** asset.decimals());
    }

    function __after() internal {
        _after.vault_totalAssets = vault.totalAssets();
        _after.vault_totalSupply = vault.totalSupply();
        _after.vault_assetBalance = asset.balanceOf(address(vault));

        _after.alice_shares = vault.balanceOf(alice);
        _after.bob_shares = vault.balanceOf(bob);

        _after.trackedAssetSum = asset.balanceOf(alice) + asset.balanceOf(bob) + asset.balanceOf(address(vault));

        _after.pricePerShare = vault.convertToShares(10 ** asset.decimals());
    }
}
