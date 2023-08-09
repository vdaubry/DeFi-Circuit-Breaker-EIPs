// SPDX-License-Identifier: CC0-1.0
pragma solidity 0.8.19;

/// @title Circuit Breaker
/// @dev See https://eips.ethereum.org/EIPS/eip-7265
interface IFreezeCircuitBreaker {
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
     * @param asset Is the asset that got frozen
     * @param amount The amount of the asset that got frozen
     */
    event AssetFrozen(address indexed asset, uint256 indexed amount);
}