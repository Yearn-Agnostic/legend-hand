// SPDX-License-Identifier: MIT


pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Legend is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each pool.
    struct PoolInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 apy; // APY 6% = 6.
        uint256 depositedAt;
        uint256 duration;
        address owner;
        bool claimed;
    }
    // Pool setting
    struct PoolSetting {
        uint256 duration; // Duration.
        uint256 apy; // APY.
    }
    /// @notice The YFIAG ERC-20 contract.
    IERC20 public immutable YFIAG;
    /// @notice The YFIAG ERC-20 contract.
    address public TREASURY;
    /// @notice Info of each user that stakes tokens.
    PoolInfo[] public poolInfo;
    /// @notice pool config setting
    mapping(uint256 => PoolSetting) public poolSetting;
    uint256 MAX_APY = 10000;
    uint256 private constant ACC_YFIAG_PRECISION = 1e12; // 6 digit after comma
    uint256 public allClaimed = 0;
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        address indexed to
    );
    event WithdrawAll(
        address indexed user,
        uint256[] indexed pids,
        uint256 amount,
        address indexed to
    );
     event EmergencyWithdraw(
        address indexed user,
        uint256 amount
    );
    event LogPoolAddition(
        uint256 indexed pid,
        uint256 amount,
        uint256 rewardDept,
        uint256 indexed apy,
        uint256 depositedAt,
        uint256 duration,
        address indexed owner
    );
    event LogUpdatePoolApySetting(uint256 indexed pid, uint256 apy);
    event LogUpdatePoolDurationSetting(uint256 indexed pid, uint256 duration);
    event LogUpdateTreasury(address indexed from, address indexed to);

    /// @param _YFIAG the YFIAG Token
    /// @param _TREASURY the YFIAG treasury for reward
    constructor(address _YFIAG, address _TREASURY) public {
        YFIAG = IERC20(_YFIAG);
        TREASURY = _TREASURY;
        poolSetting[0] = PoolSetting({duration: 5 minutes, apy: 50});
        poolSetting[1] = PoolSetting({duration: 10 minutes, apy: 200});
        poolSetting[2] = PoolSetting({duration: 15 minutes, apy: 700});
        poolSetting[3] = PoolSetting({duration: 20 minutes, apy: 2000});
    }

    /// @notice Returns the number of pools.
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /// @notice Update the given pool's setting APY. Can only be called by the owner.
    /// @param _setting The index of the pool. See `poolInfo`.
    /// @param _apy new APY of the pool
    function updatePoolApySetting(uint256 _setting, uint256 _apy)
        external
        onlyOwner
    {
        require(
            poolSetting[_setting].apy != _apy && _apy > 0,
            "Legend::updatePoolApySetting bad apy"
        );
        poolSetting[_setting].apy = _apy;
        emit LogUpdatePoolApySetting(_setting, _apy);
    }

    /// @notice Update the given pool's setting Duraion. Can only be called by the owner.
    /// @param _setting The index of the pool. See `poolInfo`.
    /// @param _duration new APY of the pool
    function updatePoolDurationSetting(uint256 _setting, uint256 _duration)
        external
        onlyOwner
    {
        require(
            poolSetting[_setting].duration != _duration && _duration > 0,
            "Legend::updatePoolDurationSetting bad duration"
        );
        poolSetting[_setting].duration = _duration;
        emit LogUpdatePoolDurationSetting(_setting, _duration);
    }

    /// @notice Update the TREASURY.
    /// @param _treasury address of new TREASURY.
    function updateTreasury(address _treasury) external onlyOwner {
        require(
            _treasury != address(0) && _treasury != TREASURY,
            "Legend::updateTreasury bad address"
        );
        address old = TREASURY;
        TREASURY = _treasury;
        emit LogUpdateTreasury(old, TREASURY);
    }

    /// @notice View function to see pending YFIAGs on frontend.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user address of user
    function pendingYFIAG(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo memory pool = poolInfo[_pid];
        require(pool.owner == _user, "Legend::pendingYFIAG not owner");
        uint256 _pendingYFIAG = 0;
        uint256 stakeTokenSupply = YFIAG.balanceOf(address(this));
        if (stakeTokenSupply != 0) {
            uint256 pass = block.timestamp - pool.depositedAt;
            if (pass > pool.duration) {
                pass = pool.duration;
            }
            if (pass > 0) {
                uint256 multiplier = pass.mul(ACC_YFIAG_PRECISION).div(
                    pool.duration
                );
                _pendingYFIAG = multiplier.mul(
                    pool.rewardDebt.div(ACC_YFIAG_PRECISION)
                );
            }
        }
        return _pendingYFIAG;
    }

    /// @notice Add a new pool.
    /// @param _amount APY of the new pool
    /// @param _poolSetting PoolSetting of the new pool
    function addPool(
        address _for,
        uint256 _amount,
        uint256 _poolSetting
    ) internal {
        uint256 apy = poolSetting[_poolSetting].apy;
        uint256 duration = poolSetting[_poolSetting].duration;
        require(apy > 0 && apy <= MAX_APY, "Legend::addPool bad apy");
        uint256 reward = _amount.mul(apy).mul(ACC_YFIAG_PRECISION.div(MAX_APY);
        poolInfo.push(
            PoolInfo({
                amount: _amount,
                rewardDebt: reward,
                apy: apy,
                depositedAt: block.timestamp,
                duration: duration,
                owner: _for,
                claimed: false
            })
        );
        uint256 pid = poolInfo.length.sub(1);
        emit LogPoolAddition(
            pid,
            _amount,
            reward,
            apy,
            block.timestamp,
            duration,
            _for
        );
    }

    /// @notice Deposit YFIAG to Legend.
    /// @param _amount The amount of yfiag
    /// @param _poolSetting The pool setting
    function deposit(uint256 _amount, uint256 _poolSetting)
        external
        nonReentrant
    {
        // Validation
        require(msg.sender != address(0), "Legend::deposit:: bad address");
        require(_amount > 0, "Legend::deposit:: bad _amount");
        require(_poolSetting >= 0, "Legend::addPool bad _poolSetting");
        require(
            msg.sender != address(TREASURY),
            "Legend::deposit:: treasury excluded"
        );
        // Interactions
        YFIAG.safeTransferFrom(address(msg.sender), address(this), _amount);
        addPool(msg.sender, _amount, _poolSetting);
        emit Deposit(msg.sender, _amount);
    }

    /// @notice Withdraw Yfiag from Legend.
    /// @param _for Receiver
    /// @param pid The index of the pool. See `poolInfo`.
    function withdraw(address _for, uint256 pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[pid];
        require(!pool.claimed, "Legend::withdraw:: already claimed");
        require(pool.owner == msg.sender, "Legend::withdraw:: only owner");
        require(pool.depositedAt != 0, "Legend::withdraw:: time invalid");
        require(
            (pool.depositedAt + pool.duration) < block.timestamp,
            "Legend::withdraw:: time invalid"
        );
        // Effects
        uint256 reward = pool.rewardDebt.div(ACC_YFIAG_PRECISION);
        uint256 amount = pool.amount;
        pool.rewardDebt = 0;
        pool.amount = 0;
        pool.claimed = true;
        allClaimed++;
        // Interactions
        YFIAG.safeTransferFrom(address(TREASURY), msg.sender, reward);
        YFIAG.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, pid, reward, _for);
    }

    /// @notice Withdraw all valid pool from Legend.
    /// @param _for Receiver
    /// @param pids The index of the pool. See `poolInfo`.
    function withdrawAll(address _for, uint256[] calldata pids)
        external
        nonReentrant
    {
        uint256 plength = pids.length;
        uint256[] memory claimedPids = new uint256[](plength);
        require(plength > 0, "Legend::withdrawAll:: bad pids array");
        uint256 l = 0;
        for (uint256 index = 0; index < plength; index++) {
            PoolInfo memory pool = poolInfo[pids[index]];
            if (
                pool.owner == msg.sender &&
                pool.depositedAt.add(pool.duration) < block.timestamp
                && !pool.claimed
            ) {
                l++;
                claimedPids[l] = pids[index];
            }
        }
        require(
            claimedPids.length > 0,
            "Legend::withdrawAll:: no valid pool"
        );
        // Effects
        uint256 reward = 0;
        uint256 amount = 0;
        for (uint256 index = 0; index < claimedPids.length; index++) {
            PoolInfo storage pool = poolInfo[claimedPids[index]];
            if (pool.amount > 0 && pool.owner != address(0)) {
                reward = reward.add(pool.rewardDebt);
                amount = amount.add(pool.amount);
                pool.rewardDebt = 0;
                pool.amount = 0;
                pool.claimed = true;
                allClaimed++;
            }
        }
        YFIAG.safeTransferFrom(address(TREASURY), msg.sender, reward);
        YFIAG.safeTransfer(msg.sender, amount);
        emit WithdrawAll(msg.sender, pids, reward, _for);
    }
    /// @notice emergencyWithdraw yfiag that somehow got stuck
    // Require all pool need to be claimed
    function emergencyWithdraw() external onlyOwner {
        require(
            poolInfo.length == allClaimed,
            "emergencyWithdraw: unclaimed pools"
        );
        uint256 amount = YFIAG.balanceOf(address(this));
        YFIAG.safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender,amount);
    }
}
