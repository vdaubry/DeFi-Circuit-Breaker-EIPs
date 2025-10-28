// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./ISettlementModule.sol";

/**
 * @title IRejectSettlementModule
 * @notice Interface for reject settlement that permanently blocks prevented transactions
 * @dev Extends ISettlementModule with rejection behavior
 *      When circuit breaker triggers, transactions are reverted immediately
 *      This is the most restrictive settlement strategy - no delayed execution possible
 *
 *      Use cases:
 *      - Maximum security protocols that can handle manual intervention
 *      - Protocols where any rate limit trigger indicates serious issues
 *      - Temporary deployment during high-risk periods
 *
 *      Note: Tokens sent to this module must be recovered manually by governance
 */
interface IRejectSettlementModule is ISettlementModule {
    // Inherits prevent() and execute() from ISettlementModule
    // - prevent() will revert the transaction
    // - execute() will always revert (rejected transactions cannot be executed)
}
