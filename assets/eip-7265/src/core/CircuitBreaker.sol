// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import {IERC7265CircuitBreaker} from "../interfaces/IERC7265CircuitBreaker.sol";
import {ISettlementModule} from "../interfaces/ISettlementModule.sol";

import {Limiter, LiqChangeNode} from "../static/Structs.sol";
import {LimiterLib, LimitStatus} from "../utils/LimiterLib.sol";

contract CircuitBreaker is IERC7265CircuitBreaker, Ownable {
    using SafeERC20 for IERC20;
    using LimiterLib for Limiter;

    ////////////////////////////////////////////////////////////////
    //                      STATE VARIABLES                       //
    ////////////////////////////////////////////////////////////////

    mapping(bytes32 identifier => Limiter limiter) public limiters;
    mapping(address _contract => bool protectionActive) public isProtectedContract;

    uint256 public immutable WITHDRAWAL_PERIOD;

    uint256 public immutable TICK_LENGTH;

    bool public isOperational = true;

    ////////////////////////////////////////////////////////////////
    //                           ERRORS                           //
    ////////////////////////////////////////////////////////////////

    error CirtcuitBreaker__NotAProtectedContract();
    error CirtcuitBreaker__NotOperational();
    error CircuitBreaker__RateLimited();

    ////////////////////////////////////////////////////////////////
    //                         MODIFIERS                          //
    ////////////////////////////////////////////////////////////////

    modifier onlyProtected() {
        if (!isProtectedContract[msg.sender]) {
            revert CirtcuitBreaker__NotAProtectedContract();
        }
        _;
    }

    /**
     * @notice When the isOperational flag is set to false, the protocol is considered locked and will
     * revert all future deposits, withdrawals, and claims to locked funds.
     * The admin should migrate the funds from the underlying protocol and what is remaining
     * in the CircuitBreaker contract to a multisig. This multisig should then be used to refund users pro-rata.
     * (Social Consensus)
     */
    modifier onlyOperational() {
        if (!isOperational) revert CirtcuitBreaker__NotOperational();
        _;
    }

    constructor(uint256 _withdrawalPeriod, uint256 _liquidityTickLength) Ownable() {
        WITHDRAWAL_PERIOD = _withdrawalPeriod;
        TICK_LENGTH = _liquidityTickLength;
    }

    /// @dev OWNER FUNCTIONS

    /// @inheritdoc IERC7265CircuitBreaker
    function addProtectedContracts(address[] calldata _ProtectedContracts) external override onlyOwner {
        for (uint256 i = 0; i < _ProtectedContracts.length; i++) {
            isProtectedContract[_ProtectedContracts[i]] = true;
        }
    }

    /// @inheritdoc IERC7265CircuitBreaker
    function removeProtectedContracts(address[] calldata _ProtectedContracts) external override onlyOwner {
        for (uint256 i = 0; i < _ProtectedContracts.length; i++) {
            isProtectedContract[_ProtectedContracts[i]] = false;
        }
    }

    /// @inheritdoc IERC7265CircuitBreaker
    function addSecurityParamter(
        bytes32 identifier,
        uint256 minLiqRetainedBps,
        uint256 limitBeginThreshold,
        address settlementModule
    ) external override onlyOwner {
        Limiter storage limiter = limiters[identifier];
        limiter.init(minLiqRetainedBps, limitBeginThreshold, ISettlementModule(settlementModule));
    }

    /// @inheritdoc IERC7265CircuitBreaker
    function updateSecurityParameter(
        bytes32 identifier,
        uint256 minLiqRetainedBps,
        uint256 limitBeginThreshold,
        address settlementModule
    ) external override onlyOwner {
        Limiter storage limiter = limiters[identifier];
        limiter.updateParams(minLiqRetainedBps, limitBeginThreshold, ISettlementModule(settlementModule));
        limiter.sync(WITHDRAWAL_PERIOD);
    }

    /// @dev function pauses the protocol and prevents any further deposits, withdrawals
    function markAsNotOperational() external override onlyOwner {
        isOperational = false;
    }

    /// @inheritdoc IERC7265CircuitBreaker
    function setParameter(
        bytes32 identifier,
        uint256 newParameter,
        address settlementTarget,
        uint256 settlementValue,
        bytes memory settlementPayload
    ) external returns (bool) {
        Limiter storage limiter = limiters[identifier];
        if (!limiter.isInitialized()) {
            return false;
        }

        // TODO: implement (have to change LimiterLib for that)

        return false;
    }

    /// @inheritdoc IERC7265CircuitBreaker
    function increaseParameter(
        bytes32 identifier,
        uint256 amount,
        address settlementTarget,
        uint256 settlementValue,
        bytes memory settlementPayload
    ) external override onlyProtected onlyOperational returns (bool) {
        return _increaseParameter(identifier, amount, settlementTarget, settlementValue, settlementPayload);
    }

    /// @inheritdoc IERC7265CircuitBreaker
    function decreaseParameter(
        bytes32 identifier,
        uint256 amount,
        address settlementTarget,
        uint256 settlementValue,
        bytes memory settlementPayload
    ) external override onlyProtected onlyOperational returns (bool) {
        return _decreaseParameter(identifier, amount, settlementTarget, settlementValue, settlementPayload);
    }

    /// @dev INTERNAL FUNCTIONS

    function _increaseParameter(
        bytes32 identifier,
        uint256 amount,
        address settlementTarget,
        uint256 settlementValue,
        bytes memory settlementPayload
    ) internal returns (bool) {
        /// @dev uint256 could overflow into negative
        Limiter storage limiter = limiters[identifier];

        emit ParameterInrease(amount, identifier);
        limiter.recordChange(int256(amount), WITHDRAWAL_PERIOD, TICK_LENGTH);
        if (limiter.status() == LimitStatus.Triggered) {
            emit RateLimited(identifier);
            limiter.settlementModule.prevent(settlementTarget, settlementValue, settlementPayload);
            return true;
        }
        return false;
    }

    function _decreaseParameter(
        bytes32 identifier,
        uint256 amount,
        address settlementTarget,
        uint256 settlementValue,
        bytes memory settlementPayload
    ) internal returns (bool) {
        Limiter storage limiter = limiters[identifier];
        // Check if the token has enforced rate limited
        if (!limiter.isInitialized()) {
            // if it is not rate limited, just return false
            return false;
        }

        emit ParameterDecrease(amount, identifier);
        limiter.recordChange(-int256(amount), WITHDRAWAL_PERIOD, TICK_LENGTH);

        // Check if rate limit is triggered after withdrawal
        if (limiter.status() == LimitStatus.Triggered) {
            emit RateLimited(identifier);
            limiter.settlementModule.prevent(settlementTarget, settlementValue, settlementPayload);
            return true;
        }
        return false;
    }
}
