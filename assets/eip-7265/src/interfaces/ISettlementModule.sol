// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @title ISettlementModule
 * @notice Base interface for settlement modules that handle triggered circuit breaker transactions
 * @dev Settlement modules determine what happens when a rate limit is triggered:
 *      - DelayedSettlementModule: Schedules transactions with a time delay for governance review
 *      - RejectSettlementModule: Permanently rejects transactions, requiring manual recovery
 *
 *      Implementations define the settlement strategy for the protocol
 */
interface ISettlementModule {
    /**
     * @notice Called by circuit breaker when a rate limit is triggered
     * @dev Different settlement modules implement different strategies:
     *      - Delayed: Schedule transaction for later execution after a time lock
     *      - Reject: Revert immediately, holding funds in settlement module
     *
     *      The circuit breaker transfers tokens/value to this contract before calling prevent()
     * @param target The address of the target contract (typically a token for transfers)
     * @param value The amount of native token to be sent with the call
     * @param innerPayload The calldata for the transaction (e.g., ERC20 transfer data)
     * @return newEffectID A unique identifier for the scheduled/prevented transaction
     */
    function prevent(
        address target,
        uint256 value,
        bytes calldata innerPayload
    ) external payable returns (bytes32 newEffectID);

    /**
     * @notice Execute a previously prevented transaction
     * @dev Implementation varies by settlement module:
     *      - Delayed: Executes after time lock expires (governance can cancel before)
     *      - Reject: Always reverts, transactions cannot be executed
     *
     *      Typically called by authorized addresses (executors, governance)
     * @param target The address of the target contract to call
     * @param value The amount of native token to send with the call
     * @param innerPayload The calldata to execute
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata innerPayload
    ) external;
}
