pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {MockERC20} from "../../../src/mocks/MockERC20.sol";
import {MockERC4626} from "../../../src/mocks/MockERC4626.sol";
import {Handler} from "./Handler.sol";

contract ERC4626_Invariants is StdInvariant, Test {
    
    MockERC20 internal asset;
    MockERC4626 internal vault;
    Handler internal handler;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    uint256 internal initialTrackedAssetSum;

    function setUp() public {
       asset = new MockERC20("Asset", "AST", 18);
       vault = new MockERC4626(asset, "Vault Share", "vAST");

       asset.mint(alice, 1_000_000e18);
       asset.mint(bob, 1_000_000e18);

       handler = new Handler(asset, vault, alice, bob);

       initialTrackedAssetSum =
            asset.balanceOf(alice) + asset.balanceOf(bob) + asset.balanceOf(address(vault));

       // teaching how 'excludeSelector' works when we want to exclude some actions from fuzzing.
       bytes4[] memory selectors = new bytes4[](1);
       selectors[0] = handler.cheat_sendAssetsAway.selector;
       excludeSelector(FuzzSelector({addr: address(handler), selectors: selectors}));

       targetContract(address(handler));
    }

    function invariant_totalAssets_matches_assetBalance() public view {
        assertEq(vault.totalAssets(), asset.balanceOf(address(vault)));
    }

    function invariant_totalSupply_equals_sumBalances() public view {
        assertEq(vault.totalSupply(), vault.balanceOf(alice) + vault.balanceOf(bob));
    }

    function invariant_limits_consistency() public view {
        assertEq(vault.maxRedeem(alice), vault.balanceOf(alice));
        assertEq(vault.maxRedeem(bob), vault.balanceOf(bob));

        assertEq(vault.maxWithdraw(alice), vault.convertToAssets(vault.balanceOf(alice)));
        assertEq(vault.maxWithdraw(bob), vault.convertToAssets(vault.balanceOf(bob)));
    }

    function invariant_asset_conservation_trackedActors() public view {
        uint256 currentSum =
            asset.balanceOf(alice) + asset.balanceOf(bob) + asset.balanceOf(address(vault));
        assertEq(currentSum, initialTrackedAssetSum);
    }
}