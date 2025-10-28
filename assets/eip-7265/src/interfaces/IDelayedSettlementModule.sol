// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./ISettlementModule.sol";

/**
 * @title IDelayedSettlementModule
 * @notice Interface for delayed settlement that uses time locks to schedule prevented transactions
 * @dev Extends ISettlementModule with time-delayed execution capabilities
 *      When circuit breaker triggers, transactions are queued rather than executed immediately
 *      This allows governance/admins time to review and potentially cancel malicious transactions
 */
interface IDelayedSettlementModule is ISettlementModule {
    /**
     * @notice Get the timestamp until which the settlement module is paused
     * @dev Used to determine if new settlements can be processed or executed
     *      Return values indicate different pause states:
     *      - 0: Not paused, normal operation
     *      - timestamp > 0 and < 2**248: Paused until that timestamp
     *      - timestamp >= 2**248: Paused indefinitely
     *
     * @return pauseTimestamp The UNIX timestamp when the pause ends (0 if not paused)
     *
     * @dev TODO: Implement pausing mechanism in DelayedSettlementModule
     *      Could be useful for emergency situations requiring full settlement halt
     */
    function pausedTill() external view returns (uint256 pauseTimestamp);
}
