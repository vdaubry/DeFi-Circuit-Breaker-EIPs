// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

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
    mapping(address _contract => bool protectionActive)
        public isProtectedContract;

<<<<<<< HEAD
    /**
     * @notice Funds locked if rate limited reached
     */
    mapping(address recipient => mapping(address asset => uint256 amount))
        public lockedFunds;

    mapping(address account => bool protectionActive)
        public isProtectedContract;
=======
    uint256 public immutable WITHDRAWAL_PERIOD;

    uint256 public immutable TICK_LENGTH;
>>>>>>> chore/limiter-lib-docs

    bool public isOperational = true;

    bool public isRateLimited;

    uint256 public rateLimitCooldownPeriod;

    uint256 public lastRateLimitTimestamp;

    uint256 public gracePeriodEndTimestamp;

    ////////////////////////////////////////////////////////////////
    //                           ERRORS                           //
    ////////////////////////////////////////////////////////////////

    error CircuitBreaker__NotAProtectedContract();
    error CircuitBreaker__NotOperational();
    error CircuitBreaker__RateLimited();
    error CircuitBreaker__NotRateLimited();
    error CircuitBreaker__InvalidGracePeriodEnd();
    error CircuitBreaker__CooldownPeriodNotReached();

    ////////////////////////////////////////////////////////////////
    //                         MODIFIERS                          //
    ////////////////////////////////////////////////////////////////

    modifier onlyProtected() {
        if (!isProtectedContract[msg.sender]) {
            revert CircuitBreaker__NotAProtectedContract();
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
        if (!isOperational) revert CircuitBreaker__NotOperational();
        _;
    }

    constructor(
        uint256 _rateLimitCooldownPeriod,
        uint256 _withdrawalPeriod,
        uint256 _liquidityTickLength,
        address _initialOwner
    ) Ownable(_initialOwner) {
        rateLimitCooldownPeriod = _rateLimitCooldownPeriod;
        WITHDRAWAL_PERIOD = _withdrawalPeriod;
        TICK_LENGTH = _liquidityTickLength;
    }

    /// @dev OWNER FUNCTIONS

<<<<<<< HEAD
    /**
     * @dev Give protected contracts one function to call for convenience
     */
    function onTokenInflow(
        address _token,
        uint256 _amount
    ) external onlyProtected onlyOperational {
        _onTokenInflow(_token, _amount);
=======
    /// @inheritdoc IERC7265CircuitBreaker
    function addProtectedContracts(
        address[] calldata _ProtectedContracts
    ) external override onlyOwner {
        for (uint256 i = 0; i < _ProtectedContracts.length; i++) {
            isProtectedContract[_ProtectedContracts[i]] = true;
        }
>>>>>>> chore/limiter-lib-docs
    }

    /// @inheritdoc IERC7265CircuitBreaker
    function removeProtectedContracts(
        address[] calldata _ProtectedContracts
    ) external override onlyOwner {
        for (uint256 i = 0; i < _ProtectedContracts.length; i++) {
            isProtectedContract[_ProtectedContracts[i]] = false;
        }
    }

<<<<<<< HEAD
    function onNativeAssetInflow(
        uint256 _amount
    ) external onlyProtected onlyOperational {
        _onTokenInflow(NATIVE_ADDRESS_PROXY, _amount);
    }

    function onNativeAssetOutflow(
        address _recipient,
        bool _revertOnRateLimit
    ) external payable onlyProtected onlyOperational {
        _onTokenOutflow(
            NATIVE_ADDRESS_PROXY,
            msg.value,
            _recipient,
            _revertOnRateLimit
        );
=======
    /// @dev CORE CIRCUIT BREAKER FUNCTIONS

    /// @inheritdoc IERC7265CircuitBreaker
    function addSecurityParameter(
        bytes32 identifier,
        uint256 minLiqRetainedBps,
        uint256 limitBeginThreshold,
        address settlementModule
    ) external override onlyOwner {
        _addSecurityParameter(
            identifier,
            minLiqRetainedBps,
            limitBeginThreshold,
            settlementModule
        );
    }

    /// @inheritdoc IERC7265CircuitBreaker
    function updateSecurityParameter(
        bytes32 identifier,
        uint256 minLiqRetainedBps,
        uint256 limitBeginThreshold,
        address settlementModule
    ) external override onlyOwner {
        _updateSecurityParameter(
            identifier,
            minLiqRetainedBps,
            limitBeginThreshold,
            settlementModule
        );
    }

    /// @inheritdoc IERC7265CircuitBreaker
    function setCircuitBreakerOperationalStatus(
        bool newOperationalStatus
    ) external override onlyOwner {
        isOperational = newOperationalStatus;
    }

    function startGracePeriod(uint256 _gracePeriodEndTimestamp) external onlyOwner {
        if (_gracePeriodEndTimestamp <= block.timestamp) revert CircuitBreaker__InvalidGracePeriodEnd();
        gracePeriodEndTimestamp = _gracePeriodEndTimestamp;
        emit GracePeriodStarted(_gracePeriodEndTimestamp);
    }

    function overrideRateLimit(bytes32 identifier) external onlyOwner {
        if (!isRateLimited) revert CircuitBreaker__NotRateLimited();
        isRateLimited = false;
        limiters[identifier].sync(WITHDRAWAL_PERIOD);
>>>>>>> chore/limiter-lib-docs
    }

    /**
     * @dev Override the status of the limiter
     * @param identifier The identifier of the limiter
     * @param overrideStatus The status to override to
     * @return The new status of the limiter
     */
    function setLimiterOverriden(
        bytes32 identifier,
        bool overrideStatus
    ) external returns (bool) {
        return limiters[identifier].overriden = overrideStatus;
    }

<<<<<<< HEAD
    function claimLockedFunds(
        address _asset,
        address _recipient
    ) external onlyOperational {
        if (lockedFunds[_recipient][_asset] == 0) revert NoLockedFunds();
        if (isRateLimited) revert RateLimited();
=======
    /// @inheritdoc IERC7265CircuitBreaker
    function increaseParameter(
        bytes32 identifier,
        uint256 amount,
        address settlementTarget,
        uint256 settlementValue,
        bytes memory settlementPayload
    ) external override returns (bool) {
        return
            _increaseParameter(
                identifier,
                amount,
                settlementTarget,
                settlementValue,
                settlementPayload
            );
    }
>>>>>>> chore/limiter-lib-docs

    /// @inheritdoc IERC7265CircuitBreaker
    function decreaseParameter(
        bytes32 identifier,
        uint256 amount,
        address settlementTarget,
        uint256 settlementValue,
        bytes memory settlementPayload
    ) external override returns (bool) {
        return
            _decreaseParameter(
                identifier,
                amount,
                settlementTarget,
                settlementValue,
                settlementPayload
            );
    }

    function overrideExpiredRateLimit() external {
        if (!isRateLimited) revert CircuitBreaker__NotRateLimited();
        if (block.timestamp - lastRateLimitTimestamp < rateLimitCooldownPeriod) {
            revert CircuitBreaker__CooldownPeriodNotReached();
        }

        isRateLimited = false;
    }

    /**
     * @dev Due to potential inactivity, the linked list may grow to where
     * it is better to clear the backlog in advance to save gas for the users
     * this is a public function so that anyone can call it as it is not user sensitive
     */
    function clearBackLog(bytes32 identifier, uint256 _maxIterations) external {
        limiters[identifier].sync(WITHDRAWAL_PERIOD, _maxIterations);
    }

<<<<<<< HEAD
    function overrideExpiredRateLimit() external {
        if (!isRateLimited) revert NotRateLimited();
        if (
            block.timestamp - lastRateLimitTimestamp < rateLimitCooldownPeriod
        ) {
            revert CooldownPeriodNotReached();
        }

        isRateLimited = false;
    }

    function registerAsset(
        address _asset,
        uint256 _minLiqRetainedBps,
        uint256 _limitBeginThreshold
    ) external onlyAdmin {
        tokenLimiters[_asset].init(_minLiqRetainedBps, _limitBeginThreshold);
        emit AssetRegistered(_asset, _minLiqRetainedBps, _limitBeginThreshold);
    }

    function updateAssetParams(
        address _asset,
        uint256 _minLiqRetainedBps,
        uint256 _limitBeginThreshold
    ) external onlyAdmin {
        Limiter storage limiter = tokenLimiters[_asset];
        limiter.updateParams(_minLiqRetainedBps, _limitBeginThreshold);
        limiter.sync(WITHDRAWAL_PERIOD);
    }

    function overrideRateLimit() external onlyAdmin {
        if (!isRateLimited) revert NotRateLimited();
        isRateLimited = false;
        // Allow the grace period to extend for the full withdrawal period to not trigger rate limit again
        // if the rate limit is removed just before the withdrawal period ends
        gracePeriodEndTimestamp = lastRateLimitTimestamp + WITHDRAWAL_PERIOD;
    }

    function addProtectedContracts(
        address[] calldata _ProtectedContracts
    ) external onlyAdmin {
        for (uint256 i = 0; i < _ProtectedContracts.length; i++) {
            isProtectedContract[_ProtectedContracts[i]] = true;
        }
    }

    function removeProtectedContracts(
        address[] calldata _ProtectedContracts
    ) external onlyAdmin {
        for (uint256 i = 0; i < _ProtectedContracts.length; i++) {
            isProtectedContract[_ProtectedContracts[i]] = false;
        }
    }

    function startGracePeriod(
        uint256 _gracePeriodEndTimestamp
    ) external onlyAdmin {
        if (_gracePeriodEndTimestamp <= block.timestamp)
            revert InvalidGracePeriodEnd();
        gracePeriodEndTimestamp = _gracePeriodEndTimestamp;
        emit GracePeriodStarted(_gracePeriodEndTimestamp);
    }

    function setAdmin(address _newAdmin) external onlyAdmin {
        if (_newAdmin == address(0)) revert InvalidAdminAddress();
        admin = _newAdmin;
        emit AdminSet(_newAdmin);
    }

    function tokenLiquidityChanges(
        address _token,
        uint256 _tickTimestamp
    ) external view returns (uint256 nextTimestamp, int256 amount) {
        LiqChangeNode storage node = tokenLimiters[_token].listNodes[
            _tickTimestamp
        ];
        nextTimestamp = node.nextTimestamp;
        amount = node.amount;
    }

    function isRateLimitTriggered(address _asset) public view returns (bool) {
        return tokenLimiters[_asset].status() == LimitStatus.Triggered;
=======
    /// @dev EXTERNAL VIEW FUNCTIONS

    function isParameterRateLimited(bytes32 identifier) external view returns (bool) {
        return limiters[identifier].status() == LimitStatus.Triggered;
>>>>>>> chore/limiter-lib-docs
    }

    function isInGracePeriod() public view returns (bool) {
        return block.timestamp <= gracePeriodEndTimestamp;
    }

    function liquidityChanges(
        bytes32 identifier,
        uint256 _tickTimestamp
    ) external view returns (uint256 nextTimestamp, int256 amount) {
        LiqChangeNode storage node = limiters[identifier].listNodes[
            _tickTimestamp
        ];
        nextTimestamp = node.nextTimestamp;
        amount = node.amount;
    }

<<<<<<< HEAD
    function migrateFundsAfterExploit(
        address[] calldata _assets,
        address _recoveryRecipient
    ) external onlyAdmin {
        if (isOperational) revert NotExploited();
        for (uint256 i = 0; i < _assets.length; i++) {
            if (_assets[i] == NATIVE_ADDRESS_PROXY) {
                uint256 amount = address(this).balance;
                if (amount > 0) {
                    _safeTransferIncludingNative(
                        _assets[i],
                        _recoveryRecipient,
                        amount
                    );
                }
            } else {
                uint256 amount = IERC20(_assets[i]).balanceOf(address(this));
                if (amount > 0) {
                    _safeTransferIncludingNative(
                        _assets[i],
                        _recoveryRecipient,
                        amount
                    );
                }
            }
        }
=======
    /// @dev INTERNAL FUNCTIONS

    function _addSecurityParameter(
        bytes32 identifier,
        uint256 minValBps,
        uint256 limitBeginThreshold,
        address settlementModule
    ) internal {
        Limiter storage limiter = limiters[identifier];
        limiter.init(
            minValBps,
            limitBeginThreshold,
            ISettlementModule(settlementModule)
        );
        emit SecurityParameterAdded(
            identifier,
            minValBps,
            limitBeginThreshold,
            settlementModule
        );
>>>>>>> chore/limiter-lib-docs
    }

    function _updateSecurityParameter(
        bytes32 identifier,
        uint256 minValBps,
        uint256 limitBeginThreshold,
        address settlementModule
    ) internal {
        Limiter storage limiter = limiters[identifier];
        limiter.updateParams(
            minValBps,
            limitBeginThreshold,
            ISettlementModule(settlementModule)
        );
        limiter.sync(WITHDRAWAL_PERIOD);
    }

    function _increaseParameter(
        bytes32 identifier,
        uint256 amount,
        address settlementTarget,
        uint256 settlementValue,
        bytes memory settlementPayload
    ) internal onlyProtected onlyOperational returns (bool) {
        /// @dev uint256 could overflow into negative
        Limiter storage limiter = limiters[identifier];

        emit ParameterInrease(amount, identifier);
        limiter.recordChange(int256(amount), WITHDRAWAL_PERIOD, TICK_LENGTH);
        if (limiter.status() == LimitStatus.Triggered && !isInGracePeriod()) {
            emit RateLimited(identifier);
            isRateLimited = true;
            _onCircuitBreakerTrigger(
                limiter,
                settlementTarget,
                settlementValue,
                settlementPayload
            );
            return true;
        }
        return false;
    }

<<<<<<< HEAD
    function _safeTransferIncludingNative(
        address _token,
        address _recipient,
        uint256 _amount
    ) internal {
        if (_amount > 0) {
            if (_token == NATIVE_ADDRESS_PROXY) {
                (bool success, ) = _recipient.call{value: _amount}("");
                if (!success) revert NativeTransferFailed();
            } else {
                IERC20(_token).safeTransfer(_recipient, _amount);
            }
=======
    function _decreaseParameter(
        bytes32 identifier,
        uint256 amount,
        address settlementTarget,
        uint256 settlementValue,
        bytes memory settlementPayload
    ) internal onlyProtected onlyOperational returns (bool) {
        Limiter storage limiter = limiters[identifier];
        // Check if the token has enforced rate limited
        if (!limiter.isInitialized()) {
            // if it is not rate limited, just return false
            return false;
>>>>>>> chore/limiter-lib-docs
        }

        emit ParameterDecrease(amount, identifier);
        limiter.recordChange(-int256(amount), WITHDRAWAL_PERIOD, TICK_LENGTH);

        // Check if rate limit is triggered after withdrawal
        if (limiter.status() == LimitStatus.Triggered && !isInGracePeriod()) {
            emit RateLimited(identifier);
            isRateLimited = true;
            _onCircuitBreakerTrigger(
                limiter,
                settlementTarget,
                settlementValue,
                settlementPayload
            );
            return true;
        }
        return false;
    }

    function _onCircuitBreakerTrigger(
        Limiter storage limiter,
        address settlementTarget,
        uint256 settlementValue,
        bytes memory settlementPayload
    ) internal virtual {
        limiter.settlementModule.prevent{value: settlementValue}(
            settlementTarget,
            settlementValue,
            settlementPayload
        );
    }
}
