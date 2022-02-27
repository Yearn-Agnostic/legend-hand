// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol';
import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol';
import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol';
import '@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol';

import "./YfiagVirtualToken.sol";
import "hardhat/console.sol";
// Main contract for farming and staking
contract MasterVault is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of YFIAGs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accCakePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accCakePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    mapping(address => uint256) public cooldownPeriodEnd;

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. YFIAGs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that YFIAGs distribution occurs.
        uint256 accYfiagPerShare; // Accumulated YFIAGs per share, times 1e12. See below.
    }

    // The YFIAG TOKEN!
    IBEP20 public yfiag;
    // The YfiagVirtualToken TOKEN!
    YfiagVirtualToken public yfiagVirtual;
    // YFIAG tokens created per block.
    uint256 public yfiagPerBlock;
    // Muliplier for early yfiag makers.
    uint256 public MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Mapping for pool tokens existance
    mapping(address => bool) public poolExistance;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when YFIAG mining starts.
    uint256 public startBlock;

    // Maximal withdrawal time
    uint256 public constant MAX_WITHDRAW_PERIOD = 72 hours;

    // Maximal withdrawal fee
    uint256 public constant MAX_WITHDRAW_FEE = 100; // 1%

    // Address of master token supplier
    address public masterSupplier;

    // Cooldown period for unstaking
    uint256 public withdrawalCooldown;

    // Fee for unstaking
    uint256 public withdrawalFee;

    // Fee collector
    address public treasury;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        IBEP20 _yfiag,
        YfiagVirtualToken _yfiagVirtual,
        address _treasury
    ) public {
        yfiag = _yfiag;
        yfiagVirtual = _yfiagVirtual;
        yfiagPerBlock = 1;
        startBlock = block.number;
        withdrawalCooldown = 0;
        withdrawalFee = 0;
        treasury = _treasury;
        // staking pool
        poolInfo.push(PoolInfo({
            lpToken: _yfiag,
            allocPoint: 1000,
            lastRewardBlock: startBlock,
            accYfiagPerShare: 0
        }));
        totalAllocPoint = 1000;
    }

    modifier supplierExcluded() {
        require(msg.sender != masterSupplier, 'supplier cannot stake here!');
        _;
    }

    function updateMasterSupplier(address newSupplier) public onlyOwner {
        masterSupplier = newSupplier;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Sets withdraw period, only callable by owner
    function setWithdrawPeriod(uint256 _withdrawPeriod) external onlyOwner {
        require(
            _withdrawPeriod <= MAX_WITHDRAW_PERIOD,
            "withdrawFeePeriod cannot be more than MAX_WITHDRAW_PERIOD"
        );
        withdrawalCooldown = _withdrawPeriod;
    }


    // Sets withdraw fee, only callable by owner
    function setWithdrawFee(uint256 _withdrawFee) external onlyOwner {
        require(
            _withdrawFee <= MAX_WITHDRAW_FEE,
            "withdrawFee cannot be more than MAX_WITHDRAW_FEE"
        );
        withdrawalFee = _withdrawFee;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IBEP20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        if (poolExistance[address(_lpToken)]) {
            return;
        }
        else {
            poolExistance[address(_lpToken)] = true;
        }

        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accYfiagPerShare: 0
        }));
        updateStakingPool();
    }

    // Update the given pool's YFIAG allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(_allocPoint);
            updateStakingPool();
        }
    }

    function updateStakingPool() internal {
        uint256 length = poolInfo.length;
        uint256 points = 0;
        for (uint256 pid = 1; pid < length; ++pid) {
            points = points.add(poolInfo[pid].allocPoint);
        }
        if (points != 0) {
            points = points.div(3);
            totalAllocPoint = totalAllocPoint.sub(poolInfo[0].allocPoint).add(points);
            poolInfo[0].allocPoint = points;
        }
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(MULTIPLIER);
    }

    // View function to see pending YFIAGs on frontend.
    function pendingYfiag(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accYfiagPerShare = pool.accYfiagPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 yfiagReward = multiplier.mul(yfiagPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accYfiagPerShare = accYfiagPerShare.add(yfiagReward.mul(1e12).div(lpSupply));
            console.log(accYfiagPerShare);
        }
        return user.amount.mul(accYfiagPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        console.log("updatePool block.number1",block.number);
        console.log("updatePool lastRewardBlock",pool.lastRewardBlock);
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 yfiagReward = multiplier.mul(yfiagPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        require(yfiag.allowance(address(masterSupplier), address(this)) >= yfiagReward, 'not enough yfiag approved on contract!');
        yfiag.transferFrom(address(masterSupplier), address(yfiagVirtual), yfiagReward);
       
        console.log("updatePool lpSupply",lpSupply);
        console.log("updatePool multiplier",multiplier);
        console.log("updatePool yfiagReward",yfiagReward);
        console.log("updatePool accYfiagPerShare",pool.accYfiagPerShare);
        console.log("updatePool",yfiagReward.mul(1e12).div(lpSupply));
        pool.accYfiagPerShare = pool.accYfiagPerShare.add(yfiagReward.mul(1e12).div(lpSupply));
        console.log("updatePool accYfiagPerShare",pool.accYfiagPerShare);
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterVault for YFIAG allocation.
    function deposit(uint256 _pid, uint256 _amount) public supplierExcluded{
        require (_pid != 0, 'deposit YFIAG by staking');
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accYfiagPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeYfiagTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accYfiagPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterVault.
    function withdraw(uint256 _pid, uint256 _amount) public supplierExcluded {
        require (_pid != 0, 'withdraw YFIAG by unstaking');
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accYfiagPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeYfiagTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accYfiagPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Stake YFIAG tokens to MasterVault
    function enterStaking(uint256 _amount) public supplierExcluded{
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accYfiagPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeYfiagTransfer(msg.sender, pending);
            }
        }
        
        if(_amount > 0) {
            cooldownPeriodEnd[msg.sender] = block.timestamp.add(this.withdrawalCooldown());
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accYfiagPerShare).div(1e12);
        yfiagVirtual.mint(msg.sender, _amount);
        emit Deposit(msg.sender, 0, _amount);
    }

    // Withdraw YFIAG tokens from STAKING.
    function leaveStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(0);
        uint256 pending = user.amount.mul(pool.accYfiagPerShare).div(1e12).sub(user.rewardDebt);
        console.log("leaveStaking Pending",pending);
        if(pending > 0) {
            safeYfiagTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            require(cooldownPeriodEnd[msg.sender] <= block.timestamp, "withdraw: not yet possible");
            uint256 fee = _amount.mul(this.withdrawalFee()).div(10000);
            uint256 userReturn = _amount.sub(fee);
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), userReturn);
            pool.lpToken.safeTransfer(address(this.treasury()), fee);
        }
        user.rewardDebt = user.amount.mul(pool.accYfiagPerShare).div(1e12);

        yfiagVirtual.burn(msg.sender, _amount);
        emit Withdraw(msg.sender, 0, _amount);
    }

    // Additional time interface for easier integration
    function timeToLeaveStaking(address user) view public returns (uint256){
        return cooldownPeriodEnd[user];
    }

    // Current supplier allowance for Yfiag 
    function currentSupplierAllowance() view public returns (uint256) {
        return yfiag.allowance(address(masterSupplier), address(this));
    }

    // Additional return estimation for easier integration
    // Average block time on Binance Smart Chain is 3s
    // Estimated daily return would be calculated over 28 800 blocks
    function getPoolInvervalReturn(uint256 poolNum, uint256 blocks) view public returns (uint256){
        uint256 poolPoints = poolInfo[poolNum].allocPoint;
        uint256 multiplier = getMultiplier(block.number, block.number.add(blocks));
        return multiplier.mul(yfiagPerBlock).mul(poolPoints).div(totalAllocPoint);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        if(_pid == 0) {
            require(cooldownPeriodEnd[msg.sender] <= block.timestamp, "withdraw: not yet possible");
        }
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe yfiag transfer function, just in case if rounding error causes pool to not have enough YFIAGs.
    function safeYfiagTransfer(address _to, uint256 _amount) internal {
        yfiagVirtual.safeYfiagTransfer(_to, _amount);
    }
}
