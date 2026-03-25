// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import '../IReactive.sol';
import '../ISubscriptionService.sol';

/**
 * @title NeuroGuardRSC
 * @notice Reactive Smart Contract deployed on Reactive Network.
 * Listens for InsuranceEvent from InsuranceOracle (Sepolia)
 * and automatically triggers InsurancePayout (Sepolia).
 * This is the "brain" — no human needed, fully automatic.
 */
contract NeuroGuardRSC is IReactive {

    // ── Constants ─────────────────────────────────────────────
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 private constant REACTIVE_IGNORE  = 0;
    uint64  private constant GAS_LIMIT        = 1000000;

    // InsuranceEvent topic:
    // keccak256("InsuranceEvent(address,uint256,uint256,uint256)")
    uint256 private constant INSURANCE_EVENT_TOPIC =
        uint256(keccak256("InsuranceEvent(address,uint256,uint256,uint256)"));

    // InsurancePayout function selector
    bytes4 private constant TRIGGER_PAYOUT_SELECTOR =
        bytes4(keccak256("triggerPayout(address,uint256,uint256)"));

    // ── State ─────────────────────────────────────────────────
    address private owner;
    address private oracleAddress;
    address private payoutAddress;
    ISubscriptionService private service;
    bool private subscribed = false;

    // ── Events ────────────────────────────────────────────────
    event CallbackSent(
        address indexed pool,
        uint256 riskScore,
        uint256 totalExposure,
        uint256 timestamp
    );

    // ── Modifiers ─────────────────────────────────────────────
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyReactive() {
        require(msg.sender == address(service), "Not Reactive service");
        _;
    }

    // ── Constructor ───────────────────────────────────────────
    constructor(
        address _service,
        address _oracleAddress,
        address _payoutAddress
    ) {
        owner         = msg.sender;
        service       = ISubscriptionService(_service);
        oracleAddress = _oracleAddress;
        payoutAddress = _payoutAddress;
        // Subscription is separate so `forge script` / local sim can deploy without
        // executing system `subscribe` in the constructor (see subscribeToOracleEvents).
    }

    /// @notice Register with Reactive subscription service (Lasna). Call once after deploy.
    function subscribeToOracleEvents() external onlyOwner {
        require(!subscribed, "Already subscribed");
        service.subscribe(
            SEPOLIA_CHAIN_ID,
            oracleAddress,
            INSURANCE_EVENT_TOPIC,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        subscribed = true;
    }

    // ── Reactive Callback ─────────────────────────────────────

    /**
     * @notice Called automatically by Reactive Network when
     *         InsuranceOracle emits InsuranceEvent on Sepolia.
     */
    function react(
        uint256 /* chain_id */,
        address /* _contract */,
        uint256 /* topic_0 */,
        uint256 topic_1,
        uint256 topic_2,
        uint256 /* topic_3 */,
        bytes calldata data,
        uint256 /* block_number */,
        uint256 /* op_code */
    ) external override {
        // Decode non-indexed params from data
        (uint256 totalExposure, uint256 timestamp) = abi.decode(
            data,
            (uint256, uint256)
        );

        address pool      = address(uint160(topic_1));
        uint256 riskScore = topic_2;

        // Build callback to InsurancePayout.triggerPayout()
        bytes memory payload = abi.encodeWithSelector(
            TRIGGER_PAYOUT_SELECTOR,
            pool,
            riskScore,
            totalExposure
        );

        // Emit callback — Reactive Network delivers this to Sepolia
        emit Callback(
            SEPOLIA_CHAIN_ID,
            payoutAddress,
            GAS_LIMIT,
            payload
        );

        emit CallbackSent(pool, riskScore, totalExposure, timestamp);
    }

    // ── Admin ─────────────────────────────────────────────────
    function updateOracleAddress(address _oracle) external onlyOwner {
        oracleAddress = _oracle;
    }

    function updatePayoutAddress(address _payout) external onlyOwner {
        payoutAddress = _payout;
    }

    function isSubscribed() external view returns (bool) {
        return subscribed;
    }

    receive() external payable {}
}