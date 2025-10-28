// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @title LiqChangeNode
 * @notice Represents a single node in the liquidity change linked list
 * @dev This struct is used to track historical liquidity changes over time
 */
struct LiqChangeNode {
    /// @notice Timestamp of the next node in the linked list (0 if this is the tail)
    uint256 nextTimestamp;
    /// @notice Liquidity change amount at this timestamp (positive for inflows, negative for outflows)
    int256 amount;
}

import {ISettlementModule} from "../interfaces/ISettlementModule.sol";

/**
 * @title Limiter
 * @notice Core data structure for tracking and enforcing rate limits on security parameters
 * @dev Maintains a linked list of liquidity changes and calculates whether limits are breached
 */
struct Limiter {
    /// @notice Minimum liquidity that must be retained, expressed in basis points (e.g., 9000 = 90%)
    uint256 minLiqRetainedBps;

    /// @notice Minimum liquidity threshold before rate limiting activates (prevents false positives for small amounts)
    uint256 limitBeginThreshold;

    /// @notice Total all-time liquidity tracked by this limiter
    int256 liqTotal;

    /// @notice Net liquidity change within the current tracking period (can be negative)
    int256 liqInPeriod;

    /// @notice Timestamp of the oldest entry in the linked list (head of the list)
    uint256 listHead;

    /// @notice Timestamp of the most recent entry in the linked list (tail of the list)
    uint256 listTail;

    /// @notice Mapping from timestamp to liquidity change node, forming a linked list
    mapping(uint256 tick => LiqChangeNode node) listNodes;

    /// @notice Settlement module to invoke when rate limit is triggered
    ISettlementModule settlementModule;

    /// @notice Flag indicating if the rate limit has been manually overridden by admin
    bool overriden;
}
