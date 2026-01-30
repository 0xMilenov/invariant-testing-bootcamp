// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

// Targets
import {Properties} from "./Properties.sol";

abstract contract TargetFunctions is Properties {
   function switchActor(uint256 entropy) public {
        uint256 n = _getActors().length;
        if (n == 0) return;
        _switchActor(entropy % n);
}

   function vault_deposit(uint256 assetsIn) public updateGhosts asActor {
        address a = _getActor();

        uint256 bal = asset.balanceOf(a);
        assetsIn = between(assetsIn, 0, bal);

        if (assetsIn == 0) return;
        if (vault.previewDeposit(assetsIn) == 0) return;

        vault.deposit(assetsIn, a);
   }

   function vault_mint(uint256 sharesOut) public updateGhosts asActor {
        address a = _getActor();

        sharesOut = between(sharesOut, 0, 1_000_000e18);

        if (sharesOut == 0) return;

        uint256 assetsIn = vault.previewMint(sharesOut);
        if (assetsIn == 0) return;

        if (assetsIn > asset.balanceOf(a)) return;

        vault.mint(sharesOut, a);
    }

    function vault_withdraw(uint256 shares) public updateGhosts asActor {
        address a = _getActor();

        uint256 maxShares = vault.maxRedeem(a);
        if (maxShares == 0) return;

        shares = between(shares, 0, maxShares);
        if (shares == 0) return;

        uint256 assetsOut = vault.convertToAssets(shares);
        if (assetsOut == 0) return;

        vault.withdraw(assetsOut, a, a);
    }

    function vault_redeem(uint256 shares) public updateGhosts asActor {
        address a = _getActor();

        uint256 maxShares = vault.maxRedeem(a);
        if (maxShares == 0) return;

        shares = between(shares, 0, maxShares);
        if (shares == 0) return;

        if (vault.previewRedeem(shares) == 0) return;

        vault.redeem(shares, a, a);
    }

}
