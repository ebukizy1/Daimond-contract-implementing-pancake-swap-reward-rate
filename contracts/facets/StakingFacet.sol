pragma solidity ^0.8.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

contract StakingFacet {
    event Stake(address _staker, uint256 _amount, uint256 _timeStaked);
    LibAppStorage.Layout internal l;

    error NoMoney(uint256 balance);
    error ID_NOT_FOUND();
    event Unstake(address indexed sender,uint indexed _amount, uint timestamp);
   
   
   

    function addPool() external {
        l.pools.push(LibAppStorage.Pool({
            accPerShare: 0,
            totalStaked: 0
        }));

    }


    function stake(uint _poolId, uint256 _amount) public {

        require(_amount > 0, "NotZero");
        require(msg.sender != address(0));
        uint256 balance = l.balances[msg.sender];
        require(balance >= _amount, "NotEnough");

        verifyPoolLength(_poolId);
        //transfer out tokens to self
        LibAppStorage._transferFrom(msg.sender, address(this), _amount);

        LibAppStorage.Pool storage pool = l.pools[_poolId];
        pool.totalStaked += _amount;

        //do staking math
        LibAppStorage.UserStake storage s = l.userDetails[msg.sender];
        s.stakedTime = block.timestamp;
        s.amount += _amount;

        updateRewardPerShare(pool, _amount);

      
        emit Stake(msg.sender, _amount, block.timestamp);
    }

    function verifyPoolLength(uint _poolId) private  view {
        if(_poolId > l.pools.length) revert ID_NOT_FOUND();
    }
    

    function checkRewards(
        address _staker
    ) public view returns (uint256 userPendingRewards) {
        LibAppStorage.UserStake memory s = l.userDetails[_staker];
        if (s.stakedTime > 0) {
            uint256 duration = block.timestamp - s.stakedTime;
            uint256 rewardPerYear = s.amount * LibAppStorage.APY;
            uint256 reward = rewardPerYear / 3154e7;
            userPendingRewards = reward * duration;
        }
    }
function checkRewards(uint256 _poolId, address _staker) public view returns (uint256 userPendingRewards) {
    LibAppStorage.UserStake memory s = l.userDetails[_staker];
        verifyPoolLength(_poolId);

    if (s.stakedTime > 0) {
        uint256 duration = block.timestamp - s.stakedTime;
        uint256 rewardPerYear = s.amount * LibAppStorage.APY;
        uint256 accruedRewards = l.pools[_poolId].accPerShare * s.amount / LibAppStorage.ACC_PER_SHARE_PRECISION; // Adjust for precision
        userPendingRewards = rewardPerYear * duration / 31540000 - accruedRewards; // Subtract already accrued rewards
    }
}


    event y(uint);

    function unstake(uint256 _poolId, uint256 _amount) public {
    LibAppStorage.UserStake storage s = l.userDetails[msg.sender];

    require(s.amount >= _amount, "InsufficientBalance");
    verifyPoolLength(_poolId);

     LibAppStorage.Pool storage pool = l.pools[_poolId];

    // Calculate the rewards that the user has already accrued
    uint256 rewardAccrued = checkRewards(_poolId, msg.sender);

    // Update pool's total staked amount
    pool.totalStaked -= _amount;

    // Update user's staking details
    l.balances[address(this)] -= _amount;
    s.amount -= _amount;
    LibAppStorage._transferFrom(address(this), msg.sender, _amount);
    s.stakedTime = s.amount > 0 ? block.timestamp : 0;

    // Transfer rewards to the user
    if (rewardAccrued > 0) {
        // Implement reward token transfer logic here
        IWOW(l.rewardToken).mint(msg.sender, rewardAccrued);
    }

    emit Unstake(msg.sender, _amount, block.timestamp);
}

    function updateRewardPerShare(LibAppStorage.Pool storage pool, uint256 _amount) private {
        if (pool.totalStaked != 0) {
        uint256 reward = LibAppStorage.REWARDRATE * _amount / pool.totalStaked;
        pool.accPerShare += reward;
    }
}
}

interface IWOW {
    function mint(address _to, uint256 _amount) external;
}
