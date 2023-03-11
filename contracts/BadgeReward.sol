// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "./BadgeConstants.sol";
import "./Errors.sol";
import "./interfaces/IUniswapPair.sol";
import "./interfaces/IBadge.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title BadgeReward
 * @author Gulshan
 * @notice It lets users stake LP and rewards them with Badges. It forms
 *         3-buckets of staked LP tokens. Time to claim badge is dependent on
 *         user's lp amount tokens falls in which bucket.
 *         It considers Uniswap style LP is being staked.
 */
contract BadgeReward is Ownable, BadgeConstants {
    /* Using */
    using SafeERC20 for IUniswapV2Pair;
    using SafeMath for uint256;

    IUniswapV2Pair public lp;

    /* Defines the minimum amount for badges */
    uint256 public minBucketAmount1;
    uint256 public minBucketAmount2;
    uint256 public minBucketAmount3;

    struct User {
        uint256 stakedAmount;
        uint256 startTime;
        uint256 nextBadgeClaimTime;
        uint256 badgeClaimed;
        bool isBadgeClaimedOnce;
    }

    /* Stores user info */
    mapping(address => User) user;

    /** Total staked LP into the contract */
    uint256 public totalStakedLP;

    /** Address of nft badge contracts */
    IBadge public badge1;
    IBadge public badge2;
    IBadge public badge3;

    /** Minimum waiting periods */
    uint256 public minWaitingBucket1;
    uint256 public minWaitingBucket2;
    uint256 public minWaitingBucket3;

    /**
     * Constructor
     * It would set `lp` token which is allowed for staking.
     */
    constructor(
        IUniswapV2Pair _lp,
        IBadge _badge1,
        IBadge _badge2,
        IBadge _badge3,
        uint256 _minWaitingBucket1,
        uint256 _minWaitingBucket2,
        uint256 _minWaitingBucket3
    ) public {
        lp = _lp;
        badge1 = _badge1;
        badge2 = _badge2;
        badge3 = _badge3;
        minWaitingBucket1 = _minWaitingBucket1;
        minWaitingBucket2 = _minWaitingBucket2;
        minWaitingBucket3 = _minWaitingBucket3;
    }

    /**
     * It allows to stake `lp` tokens.
     * @param _amount Number of lp tokens to be staked.
     */
    function stake(uint256 _amount) external {
        if (_amount == 0) {
            revert Errors.ZeroAmount();
        }

        SafeERC20.safeTransferFrom(
            IERC20(address(lp)),
            msg.sender,
            address(this),
            _amount
        );

        User storage userObj = user[msg.sender];

        if (userObj.stakedAmount == 0) {
            userObj.startTime = block.timestamp;
            userObj.nextBadgeClaimTime = block.timestamp + getDuration(_amount);
        } else {
            userObj.stakedAmount = userObj.stakedAmount + _amount;
            userObj.nextBadgeClaimTime =
                block.timestamp +
                getDuration(userObj.stakedAmount);
        }

        totalStakedLP = totalStakedLP + _amount;
    }

    /**
     * Withraws staked `lp` tokens.
     * @param _amount Number of lp tokens to be staked.
     */
    function withdraw(uint256 _amount) external {
        if (_amount == 0) {
            revert Errors.ZeroAmount();
        }
        _withdraw(_amount);
    }

    /**
     * @notice User withdraws LP tokens. User is not eligilbe for any badge
     *         if user claims entire LP tokens. Claim period is reset based on
     *         user's remaining user lp tokens.
     *
     * @param _amount Amount of LP to be withdrawn
     */
    function _withdraw(uint256 _amount) internal {
        User storage userObj = user[msg.sender];
        userObj.stakedAmount = userObj.stakedAmount - _amount;

        SafeERC20.safeTransfer(IERC20(address(lp)), msg.sender, _amount);

        // If lp tokens are directly claimed without waiting, then user would
        // not get the badge
        if (userObj.stakedAmount == _amount) {
            // full amount is being withdrawn
            userObj.nextBadgeClaimTime = 0;
        } else {
            // partial amount is being withdrawn
            userObj.nextBadgeClaimTime =
                block.timestamp +
                getDuration(userObj.stakedAmount);
        }
        totalStakedLP = totalStakedLP - _amount;
    }

    /**
     * @notice User can claim badge.
     *
     * @dev Below conditions must be satisfied :
     *      1. User cannot claim same badge again and again.
     *      2. User cannot claim more than badge id 2.
     *
     * @param _badgeType Type of badge to be claimed
     */
    function claimBadge(uint256 _badgeType) external {
        User storage userObj = user[msg.sender];

        // User is claiming the same badge again.
        if (
            userObj.isBadgeClaimedOnce && (_badgeType == userObj.badgeClaimed)
        ) {
            revert Errors.BadgeAlreadyClaimed();
        }

        if (!userObj.isBadgeClaimedOnce) {
            userObj.isBadgeClaimedOnce = true;
        }

        if (userObj.badgeClaimed >= 2) {
            revert Errors.AllBadgesAlreadyClaimed();
        }

        uint256 userBadge = (_badgeType > userObj.badgeClaimed)
            ? _badgeType
            : userObj.badgeClaimed;

        if (userObj.nextBadgeClaimTime >= block.timestamp) {
            IBadge badgeNFT = getBadge(userBadge);
            badgeNFT.mint(msg.sender);
        }

        userObj.nextBadgeClaimTime =
            block.timestamp +
            getDuration(userObj.stakedAmount);
    }

    /**
     * @notice Returns badge contract address.
     * @param _badgeType Id of the badge
     */
    function getBadge(uint256 _badgeType) public view returns (IBadge badge) {
        if (_badgeType == BadgeConstants.LEVEL_1) {
            return badge1;
        } else if (_badgeType == BadgeConstants.LEVEL_2) {
            return badge2;
        }

        return badge3;
    }

    /**
     * Returns minimum waiting period based on amount of lp tokens staked.
     * @param _amount Total amount of LP staked  
     */
    function getDuration(uint256 _amount) public view returns (uint256) {
        if (_amount <= minBucketAmount1) {
            return minWaitingBucket1;
        } else if (_amount <= minBucketAmount2) {
            return minWaitingBucket2;
        }

        return minWaitingBucket3;
    }
}
