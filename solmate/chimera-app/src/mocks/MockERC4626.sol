// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {SolmateERC4626} from "../SolmateERC4626.sol";

/// @notice A bare-minimum concrete vault: assets are just held on this contract.
contract MockERC4626 is SolmateERC4626 {
    constructor(ERC20 _asset, string memory _name, string memory _symbol) SolmateERC4626(_asset, _name, _symbol) {}

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }
}
