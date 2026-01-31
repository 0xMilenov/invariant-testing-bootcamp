pragma solidity 0.8.24;

import {RewardsManager} from "../../src/RewardsManager.sol";

contract MockVault{
  
  RewardsManager public immutable rewardsManager;

  mapping(address => uint256) public shareBalance;
  uint256 public totalShares;

  constructor(address _rewardsManager) {
    rewardsManager = RewardsManager(_rewardsManager);
  }

  function mintShares(address to, uint256 amount) external {
    shareBalance[to] += amount;
    totalShares += amount;
    rewardsManager.notifyTransfer(address(0), to, amount);
  }

  function burnShares(address from, uint256 amount) external {
    require(shareBalance[from] >= amount, "VAULT_BAL");
    shareBalance[from] -= amount;
    totalShares -= amount;
    rewardsManager.notifyTransfer(from, address(0), amount);
  }

  function transferShares(address from, address to, uint256 amount) external {
    require(from != to, "VAULT_SAME");
    require(shareBalance[from] >= amount, "VAULT_BAL");
    shareBalance[from] -= amount;
    shareBalance[to] += amount;
    rewardsManager.notifyTransfer(from, to, amount);
  }

}