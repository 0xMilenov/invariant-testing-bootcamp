pragma solidity 0.8.24;

import {MintableERC20} from "./MintableERC20.sol";

contract FeeOnTransferERC20 is MintableERC20 {

  // fee in bps - 100 = 1%
  uint256 public immutable feeBps;
  address public immutable feeCollector;

  constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _feeBps, address _feeCollector) MintableERC20(_name, _symbol, _decimals) {
    feeBps = _feeBps;
    feeCollector = _feeCollector;
  }

  function transfer(address to, uint256 amount) external override returns (bool) {
    _transferWithFee(msg.sender, to, amount); 
    return true;
  }

  function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
    uint256 allowed = allowance[from][msg.sender];
    require(allowed >= amount, "ALLOWANCE");
    if (allowed != type(uint256).max) {
      allowance[from][msg.sender] = allowed - amount;
      emit Approval(from, msg.sender, allowance[from][msg.sender]);
    }
    _transferWithFee(from, to, amount);
    return true;
  }

  function _transferWithFee(address from, address to, uint256 amount) internal {
    require(balanceOf[from] >= amount, "BALANCE");
    uint256 fee = (amount * feeBps) / 10_000;
    uint256 net = amount - fee;

    balanceOf[from] -= amount;
    balanceOf[to] += net;
    emit Transfer(from, to, net);

    if (fee > 0) {
      balanceOf[feeCollector] += fee;
      emit Transfer(from, feeCollector, fee);
    }
  }
}