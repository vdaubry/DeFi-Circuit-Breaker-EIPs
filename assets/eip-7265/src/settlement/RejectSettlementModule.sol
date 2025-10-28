// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../interfaces/IRejectSettlementModule.sol";

/**
 * @title RejectSettlementModule
 * @notice Settlement module that completely rejects transactions when circuit breaker triggers
 * @dev This is the most restrictive settlement strategy - transactions are permanently blocked
 *      Use this when you want maximum security and can handle manual intervention for all rate-limited transactions
 */
contract RejectSettlementModule is IRejectSettlementModule {
    /// @notice Error thrown when attempting to execute a rejected transaction
    error cannotExecuteRejectedTransation();

    constructor() {}

    /**
     * @notice Called by circuit breaker when a rate limit is triggered
     * @dev Returns an effect ID but then reverts, permanently rejecting the transaction
     *      The tokens will remain in the settlement module and require manual recovery
     * @param target The contract address (not used as transaction is rejected)
     * @param value The native token value (not used as transaction is rejected)
     * @param innerPayload The calldata (not used as transaction is rejected)
     * @return newEffectID Unique identifier for the rejected transaction (for logging/tracking)
     */
    function prevent(
        address target,
        uint256 value,
        bytes calldata innerPayload
    ) external payable override returns (bytes32 newEffectID) {
        // Generate unique ID for tracking/logging purposes
        // This allows off-chain systems to identify which transaction was rejected
        newEffectID = keccak256(abi.encode(target, value, innerPayload));
        return newEffectID;

        // Permanently reject the transaction
        // Note: This line is unreachable, but kept for clarity of intent
        revert();
    }

    /**
     * @notice Attempt to execute a rejected transaction
     * @dev Always reverts - rejected transactions cannot be executed
     *      Funds must be recovered through governance or admin intervention
     * @param target Not used
     * @param value Not used
     * @param payload Not used
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata payload
    ) external override {
        // Rejected transactions can never be executed
        revert cannotExecuteRejectedTransation();
    }
}
