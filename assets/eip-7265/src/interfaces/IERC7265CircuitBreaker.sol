// SPDX-License-Identifier: CC0-1.0
pragma solidity 0.8.19;

/// @title Circuit Breaker
/// @dev See https://eips.ethereum.org/EIPS/eip-7265
interface IERC7265CircuitBreaker {
    /**
     * @notice Event emitted whenever the security parameter is increased
     * @param amount The amount by which the security parameter is increased
     * @param identifier The identifier of the security parameter
     */
    event ParameterInrease(uint256 indexed amount, bytes32 indexed identifier);
    /**
     * @notice Event emitted whenever the security parameter is decreased
     * @param amount The amount by which the security parameter is decreased
     * @param identifier The identifier of the security parameter
     */
    event ParameterDecrease(uint256 indexed amount, bytes32 indexed identifier);
    /**
     * @notice Event emitted whenever the security parameter is directly set to a new value
     * @param previousParameter The previous value of the security parameter
     * @param newParameter The new value of the security parameter
     * @param identifier The identifier of the security parameter
     */
    event ParameterSet(uint256 indexed previousParameter, uint256 indexed newParameter, bytes32 indexed identifier);
    /**
     * @notice Event emitted whenever an interaction is rate limited
     * @param identifier The identifier of the security parameter that triggered the rate limiting
     */
    event RateLimited(bytes32 indexed identifier);

    /**
     * @notice Function for setting the security parameter to a new value
     * @dev This function MAY only be called by the owner of the security parameter
     * // bytes32 identifier
     * // revertOnRateLimit
     * The function MUST emit the {ParameterSet} event
     */
    function setParameter(bytes32 identifier, uint256 newParameter, bool revertOnRateLimit) external returns(bool);

    /**
     * @notice Function for increasing the current security parameter
     * @dev This function MAY only be called by the owner of the security parameter
     * // bytes32 identifier
     * // revertOnRateLimit
     * The function MUST emit the {ParameterSet} event
     */
    function increaseParameter(bytes32 identifier, uint256 amount, bool revertOnRateLimit) external returns(bool);

    /**
     * @notice Function for decreasing the current security parameter
     * @dev This function MAY only be called by the owner of the security parameter
     * // bytes32 identifier
     * // revertOnRateLimit
     * The function MUST emit the {ParameterSet} event
     */
    function decreaseParameter(bytes32 identifier, uint256 amount, bool revertOnRateLimit) external returns(bool);

    /**
     * @dev MAY be called by admin to configure a security parameter
     */
    function addSecurityParamter(bytes32 identifier, uint256 minLiqRetainedBps, uint256 limitBeginThreshold) external;

    /**
     * @dev MAY be called by admin to update configuration of a security parameter
     */
    function updateSecurityParameter(bytes32 identifier, uint256 minLiqRetainedBps, uint256 limitBeginThreshold) external;

    /**
     * @dev MAY be called by admin to add protected contracts
     */
    function addProtectedContracts(address[] calldata _protectedContracts) external;

    /**
     * @dev MAY be called by admin to add protected contracts
     */
    function removeProtectedContracts(address[] calldata _protectedContracts) external;

    /// @notice Lock the circuit breaker
    /// @dev MAY be called by admin to lock the circuit breaker
    /// While the protocol is not operational: inflows, outflows, and claiming locked funds MUST revert
    function markAsNotOperational() external;
}