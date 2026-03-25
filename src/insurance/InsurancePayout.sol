// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title InsurancePayout
 * @notice Destination contract deployed on Sepolia.
 * Receives callbacks from NeuroGuardRSC (via Reactive Network)
 * and automatically pays out compensation to LPs when a
 * black swan event is detected.
 */
contract InsurancePayout {

    // ── Events ────────────────────────────────────────────────
    event PayoutTriggered(
        address indexed pool,
        address indexed recipient,
        uint256 amount,
        uint256 riskScore,
        uint256 timestamp
    );

    event FundsDeposited(address indexed depositor, uint256 amount);

    // ── State ─────────────────────────────────────────────────
    address public owner;
    address public callbackSender; // Reactive Network callback address

    mapping(address => uint256) public lpBalances;   // LP deposits
    mapping(address => bool)    public registeredLPs; // registered LPs
    address[] public lpList;

    uint256 public totalInsuranceFund;
    uint256 public payoutPercentage = 10; // pay 10% of exposure per event

    // ── Modifiers ─────────────────────────────────────────────
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyReactive() {
        require(
            msg.sender == callbackSender,
            "Only Reactive Network callback allowed"
        );
        _;
    }

    // ── Constructor ───────────────────────────────────────────
    constructor(address _callbackSender) {
        owner         = msg.sender;
        callbackSender = _callbackSender;
    }

    // ── LP Registration ───────────────────────────────────────

    /// @notice LPs deposit ETH into the insurance fund
    function depositInsuranceFund() external payable {
        require(msg.value > 0, "Must deposit ETH");
        lpBalances[msg.sender] += msg.value;
        totalInsuranceFund     += msg.value;

        if (!registeredLPs[msg.sender]) {
            registeredLPs[msg.sender] = true;
            lpList.push(msg.sender);
        }

        emit FundsDeposited(msg.sender, msg.value);
    }

    // ── Reactive Callback ─────────────────────────────────────

    /**
     * @notice Called automatically by Reactive Network when
     *         InsuranceOracle emits an InsuranceEvent.
     * @param pool          The affected Uniswap pool
     * @param riskScore     Score from the oracle (0-100)
     * @param totalExposure Total LP funds at risk
     */
    function triggerPayout(
        address pool,
        uint256 riskScore,
        uint256 totalExposure
    ) external onlyReactive {
        require(totalInsuranceFund > 0, "Insurance fund empty");

        // Calculate payout: higher risk = higher payout %
        uint256 dynamicPct = riskScore >= 90 ? 20 : payoutPercentage;
        uint256 payoutPool = (totalExposure * dynamicPct) / 100;

        // Cap payout at available fund
        if (payoutPool > totalInsuranceFund) {
            payoutPool = totalInsuranceFund;
        }

        // Distribute proportionally to all registered LPs
        uint256 lpCount = lpList.length;
        for (uint256 i = 0; i < lpCount; i++) {
            address lp     = lpList[i];
            uint256 share  = (lpBalances[lp] * payoutPool) / totalInsuranceFund;

            if (share > 0) {
                lpBalances[lp]     -= share;
                totalInsuranceFund -= share;

                (bool ok, ) = lp.call{value: share}("");
                require(ok, "Payout transfer failed");

                emit PayoutTriggered(pool, lp, share, riskScore, block.timestamp);
            }
        }
    }

    // ── Admin ─────────────────────────────────────────────────
    function setPayoutPercentage(uint256 pct) external onlyOwner {
        require(pct <= 50, "Max 50%");
        payoutPercentage = pct;
    }

    function setCallbackSender(address _sender) external onlyOwner {
        callbackSender = _sender;
    }

    function getInsuranceFund() external view returns (uint256) {
        return totalInsuranceFund;
    }

    function getLPCount() external view returns (uint256) {
        return lpList.length;
    }

    // Allow contract to receive ETH
    receive() external payable {}
}