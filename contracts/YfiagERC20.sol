// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract YfiagERC20 is ERC20 {

    constructor() ERC20("YFIAG","YFIAG") public {
        _mint(msg.sender, 1000000000 ether);
    }
}
