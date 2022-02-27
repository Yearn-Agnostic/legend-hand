// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
contract YfiagTreasury is Ownable{

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IERC20 public YFIAG;
    mapping (address => uint256) public coolDown;
    uint constant MAX_COOLDOWN = 5 minutes;

    constructor(address yfiag) public {
        YFIAG = IERC20(yfiag);
    }
    function balanceOf() public view returns (uint256) {
        return YFIAG.balanceOf(address(this));
    } 
    function faucet(address _for, uint256 _amount) public{
        require(_for!= address(0),"Bad address");
        require(coolDown[_for].add(MAX_COOLDOWN) <= block.timestamp,"Cooldown");
        require(YFIAG.balanceOf(address(this)) >= _amount, "Bad balance");
        coolDown[_for] = block.timestamp;
        YFIAG.safeTransfer(_for,_amount);
    }

}
