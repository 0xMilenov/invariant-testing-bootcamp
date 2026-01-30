// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Targets
import {Actor} from "./Setup.sol";
import {Properties} from "./Properties.sol";

abstract contract TargetFunctions is Properties {
    function switchActor(uint256 entropy) public {
        _switchActor((entropy % 2) + 1); // 1 => alice, 2 => bob
    }

    function vault_deposit(uint256 assetsIn) public updateGhosts {
        address a = _getActor();

        uint256 bal = asset.balanceOf(a);
        assetsIn = between(assetsIn, 0, bal);

        if (assetsIn == 0) return;
        if (vault.previewDeposit(assetsIn) == 0) return;

        Actor(a).deposit(assetsIn);
    }

    function vault_mint(uint256 sharesOut) public updateGhosts {
        address a = _getActor();

        sharesOut = between(sharesOut, 0, 1_000_000e18);

        if (sharesOut == 0) return;

        uint256 assetsIn = vault.previewMint(sharesOut);
        if (assetsIn == 0) return;

        if (assetsIn > asset.balanceOf(a)) return;

        Actor(a).mint(sharesOut);
    }

    function vault_withdraw(uint256 shares) public updateGhosts {
        address a = _getActor();

        uint256 maxShares = vault.maxRedeem(a);
        if (maxShares == 0) return;

        shares = between(shares, 0, maxShares);
        if (shares == 0) return;

        uint256 assetsOut = vault.convertToAssets(shares);
        if (assetsOut == 0) return;

        Actor(a).withdraw(assetsOut);
    }

    function vault_redeem(uint256 shares) public updateGhosts {
        address a = _getActor();

        uint256 maxShares = vault.maxRedeem(a);
        if (maxShares == 0) return;

        shares = between(shares, 0, maxShares);
        if (shares == 0) return;

        if (vault.previewRedeem(shares) == 0) return;

        Actor(a).redeem(shares);
    }

}
