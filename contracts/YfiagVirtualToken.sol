// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol';

contract YfiagVirtualToken is BEP20('Yfiag virtual token', 'YFIAGV') {
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    function burn(address _from ,uint256 _amount) public onlyOwner {
        _burn(_from, _amount);
    }

    IBEP20 public yfiag;

    constructor(
        IBEP20 _yfiag
    ) public {
        yfiag = _yfiag;
    }

    // Safe yfiag transfer function, just in case if rounding error causes pool to not have enough YFIAGs.
    function safeYfiagTransfer(address _to, uint256 _amount) public onlyOwner {
        uint256 yfiagBal = yfiag.balanceOf(address(this));
        if (_amount > yfiagBal) {
            yfiag.transfer(_to, yfiagBal);
        } else {
            yfiag.transfer(_to, _amount);
        }
    }
}
