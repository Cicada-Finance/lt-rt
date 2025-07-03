// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./utils/Ownable.sol";
import "./utils/SafeMath.sol";

contract rtAutoRebase is Ownable {
    using SafeMath for uint256;

    uint256 public start;
    uint256 public totalAmount;
    uint256 private constant PRECISION = 1e27;
    uint256 public initialDailyRelease = 600000000 * 1e18;
    uint256 private constant GROWTH_RATE = 21050299076457;
    uint256 private constant GROWTH_RATE_DENOMINATOR = 1e16;

    constructor(address owner) Ownable(owner) {
        start = block.timestamp;
        totalAmount = 6000000000 * 1e18;
    }

    function setConfig(uint256 _start, uint256 _totalAmount) external onlyOwner {
        start = _start;
        totalAmount = _totalAmount;
    }

    function rebaseAmount() public view returns (uint256) {
        if (block.timestamp < start) {
            return 0;
        }

        uint256 daysPassed = (block.timestamp - start) / 1 days;
        uint256 growthFactor = calculateGrowthFactor(daysPassed);
        uint256 theoreticalCumulativeRelease = (initialDailyRelease * growthFactor) / PRECISION;

        if (theoreticalCumulativeRelease > totalAmount) {
            return totalAmount - initialDailyRelease;
        }

        return theoreticalCumulativeRelease - initialDailyRelease;
    }
    function calculateGrowthFactor(uint256 _daysPassed) internal pure returns (uint256) {
        uint256 base = PRECISION.add(GROWTH_RATE.mul(PRECISION).div(GROWTH_RATE_DENOMINATOR));

        uint256 result = PRECISION;
        uint256 remainingExp = _daysPassed;
        uint256 currentBase = base;

        while (remainingExp > 0) {
            if (remainingExp % 2 == 1) {
                result = result.mul(currentBase).div(PRECISION);
            }
            remainingExp = remainingExp / 2;
            currentBase = currentBase.mul(currentBase).div(PRECISION);
        }
        return result;
    }
}
