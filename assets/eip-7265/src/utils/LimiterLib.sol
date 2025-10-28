// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Limiter, LiqChangeNode} from "../static/Structs.sol";
import {SafeCast} from "openzeppelin-contracts/utils/math/SafeCast.sol";
import {ISettlementModule} from "../interfaces/ISettlementModule.sol";

// BPS = Basis Points : 1 Basis Point is equivalent to 0.01%
uint256 constant BPS_DENOMINATOR = 10000;

enum LimitStatus {
    Uninitialized,
    Inactive,
    Ok,
    Triggered
}

/**
 * @title LimiterLib
 * @dev Set of tools to track a security parameter over a specific time period.
 * @dev It offers tools to record changes, enforce limits based on set thresholds, and maintain a historical view of the security parameter.
 */
library LimiterLib {
    error InvalidMinimumLiquidityThreshold();
    error LimiterAlreadyInitialized();
    error LimiterNotInitialized();

    /**
     * @notice Initialize the limiter
     * @param limiter The limiter to initialize
     * @param minLiqRetainedBps The minimum liquidity that MUST be retained in percent
     * @param limitBeginThreshold The minimal amount of a security parameter that MUST be reached before the Circuit Breaker checks for a breach
     * @param settlementModule The address of the settlement module chosen when the CircuitBreaker triggers
     */
    function init(
        Limiter storage limiter,
        uint256 minLiqRetainedBps,
        uint256 limitBeginThreshold,
        ISettlementModule settlementModule
    ) internal {
        // MUST define a minimum liquidity threshold > 0% and < 100%
        if (minLiqRetainedBps == 0 || minLiqRetainedBps > BPS_DENOMINATOR) {
            revert InvalidMinimumLiquidityThreshold();
        }
        if (isInitialized(limiter)) revert LimiterAlreadyInitialized();
        limiter.minLiqRetainedBps = minLiqRetainedBps;
        limiter.limitBeginThreshold = limitBeginThreshold;
        limiter.settlementModule = settlementModule;
    }

    /**
     * @notice Update the limiter parameters
     * @param limiter The limiter to update
     * @param minLiqRetainedBps The minimum liquidity that MUST be retained in percent
     * @param limitBeginThreshold The minimal amount of a security parameter that MUST be reached before the Circuit Breaker checks for a breach
     * @param settlementModule The address of the settlement module chosen when the CircuitBreaker triggers
     */
    function updateParams(
        Limiter storage limiter,
        uint256 minLiqRetainedBps,
        uint256 limitBeginThreshold,
        ISettlementModule settlementModule
    ) internal {
        if (minLiqRetainedBps == 0 || minLiqRetainedBps > BPS_DENOMINATOR) {
            revert InvalidMinimumLiquidityThreshold();
        }
        if (!isInitialized(limiter)) revert LimiterNotInitialized();
        limiter.minLiqRetainedBps = minLiqRetainedBps;
        limiter.limitBeginThreshold = limitBeginThreshold;
        limiter.settlementModule = settlementModule;
    }

    /**
     * @notice Record a change in the security parameter
     * @dev This function maintains a linked list of liquidity changes over time, allowing historical tracking
     * @param limiter The limiter to record the change for
     * @param amount The amount of the change (positive for inflows, negative for outflows)
     * @param withdrawalPeriod The period over which the change is recorded
     * @param tickLength Unit of time to consider in seconds
     */
    function recordChange(
        Limiter storage limiter,
        int256 amount,
        uint256 withdrawalPeriod,
        uint256 tickLength
    ) internal {
        // If token does not have a rate limit, do nothing
        if (!isInitialized(limiter)) {
            return;
        }

        // All transactions that occur within a given tickLength will have the same currentTickTimestamp
        // This groups transactions together for efficient tracking
        uint256 currentTickTimestamp = getTickTimestamp(
            block.timestamp,
            tickLength
        );

        // Update total liquidity change in the current period
        limiter.liqInPeriod += amount;

        uint256 listHead = limiter.listHead;
        if (listHead == 0) {
            // Initialize the linked list with the first node
            // Both head and tail point to the same node initially
            limiter.listHead = currentTickTimestamp;
            limiter.listTail = currentTickTimestamp;
            limiter.listNodes[currentTickTimestamp] = LiqChangeNode({
                amount: amount,
                nextTimestamp: 0  // No next node yet
            });
        } else {
            // Linked list already exists
            // Check if the oldest entry (head) has expired beyond the withdrawal period
            if (block.timestamp - listHead >= withdrawalPeriod) {
                // Remove expired entries from the linked list to maintain accurate period tracking
                sync(limiter, withdrawalPeriod);
            }

            // Check if the current tick already has an entry (multiple txs in same tick)
            uint256 listTail = limiter.listTail;
            if (listTail == currentTickTimestamp) {
                // Aggregate amount with existing entry for this tick
                limiter.listNodes[currentTickTimestamp].amount += amount;
            } else {
                // Create a new node and append it to the tail of the linked list
                limiter
                    .listNodes[listTail]
                    .nextTimestamp = currentTickTimestamp;  // Link previous tail to new node
                limiter.listNodes[currentTickTimestamp] = LiqChangeNode({
                    amount: amount,
                    nextTimestamp: 0  // This is now the new tail
                });
                limiter.listTail = currentTickTimestamp;
            }
        }
    }

    /**
     * @notice Sync the limiter
     * @param limiter The limiter to sync
     * @param withdrawalPeriod the max period to keep track of
     */
    function sync(Limiter storage limiter, uint256 withdrawalPeriod) internal {
        sync(limiter, withdrawalPeriod, type(uint256).max);
    }

    /**
     * @notice Sync the limiter to clear old data
     * @dev Removes expired entries from the linked list and updates liquidity tracking
     * @param limiter The limiter to sync
     * @param withdrawalPeriod The max period to keep track of
     * @param totalIters The max number of iterations to perform (prevents gas exhaustion)
     */
    function sync(
        Limiter storage limiter,
        uint256 withdrawalPeriod,
        uint256 totalIters
    ) internal {
        uint256 currentHead = limiter.listHead;
        int256 totalChange = 0;
        uint256 iter = 0;

        // Traverse the linked list from head, removing expired nodes
        // Stop when: 1) list is empty, 2) found a non-expired node, 3) hit iteration limit
        while (
            currentHead != 0 &&
            block.timestamp - currentHead >= withdrawalPeriod &&
            iter < totalIters
        ) {
            LiqChangeNode storage node = limiter.listNodes[currentHead];

            // Accumulate the amount from expired nodes to update totals later
            totalChange += node.amount;

            uint256 nextTimestamp = node.nextTimestamp;

            // Clear the expired node data to free storage
            limiter.listNodes[currentHead];

            // Move to the next node in the list
            currentHead = nextTimestamp;

            // forgefmt: disable-next-item
            unchecked {
                ++iter;  // Safe to not check overflow as totalIters is reasonable
            }
        }

        if (currentHead == 0) {
            // If the list is now empty after cleanup, reset head and tail to current time
            // This prevents issues when recording new changes
            limiter.listHead = block.timestamp;
            limiter.listTail = block.timestamp;
        } else {
            // Update the head to point to the first non-expired node
            limiter.listHead = currentHead;
        }

        // Move expired amounts from liqInPeriod to liqTotal
        // liqTotal tracks all-time liquidity, liqInPeriod tracks recent period liquidity
        limiter.liqTotal += totalChange;
        limiter.liqInPeriod -= totalChange;
    }

    /**
     * @notice Get the status of the limiter
     * @dev Determines whether the limiter should trigger a rate limit based on liquidity thresholds
     * @param limiter The limiter to get the status for
     * @return The status of the limiter (Uninitialized, Inactive, Ok, or Triggered)
     */
    function status(
        Limiter storage limiter
    ) internal view returns (LimitStatus) {
        // Check if the limiter has been configured
        if (!isInitialized(limiter)) {
            return LimitStatus.Uninitialized;
        }

        // Check if admin has manually overridden the rate limit
        if (limiter.overriden) {
            return LimitStatus.Ok;
        }

        int256 currentLiq = limiter.liqTotal;

        // Only enforce rate limit if there is significant liquidity
        // This prevents false positives for low-liquidity assets or during protocol launch
        if (limiter.limitBeginThreshold > uint256(currentLiq)) {
            return LimitStatus.Inactive;
        }

        // Calculate projected future liquidity by adding period changes to current total
        int256 futureLiq = currentLiq + limiter.liqInPeriod;

        // Calculate minimum allowed liquidity as a percentage of current liquidity
        // NOTE: uint256 to int256 conversion here is safe as values are within bounds
        int256 minLiq = (currentLiq * int256(limiter.minLiqRetainedBps)) /
            int256(BPS_DENOMINATOR);

        // Trigger rate limit if future liquidity would drop below minimum threshold
        return futureLiq < minLiq ? LimitStatus.Triggered : LimitStatus.Ok;
    }

    /**
     * @notice Get the current liquidity
     * @param limiter The limiter to get the liquidity for
     * @return Has the minLiqRetainedBps of the Limiter been set ?
     */
    function isInitialized(
        Limiter storage limiter
    ) internal view returns (bool) {
        return limiter.minLiqRetainedBps > 0;
    }

    /**
     * @notice Get the timestamp for the current period (as defined by ticklength)
     * @param t The current timestamp
     * @param tickLength The tick length
     * @return The current tick timestamp
     */
    function getTickTimestamp(
        uint256 t,
        uint256 tickLength
    ) internal pure returns (uint256) {
        return t - (t % tickLength);
    }
}
