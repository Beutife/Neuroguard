// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title InsuranceOracle
 * @notice Origin contract deployed on Sepolia.
 * Monitors LP risk metrics and emits an InsuranceEvent
 * when a black swan / high-risk condition is detected.
 * The Reactive Smart Contract (NeuroGuardRSC) listens
 * for this event and triggers automatic LP compensation.
 */
contract InsuranceOracle {

    // ── Events ────────────────────────────────────────────────
    /// @notice Emitted when a high-risk condition is detected
    event InsuranceEvent(
        address indexed pool,
        uint256 riskScore,      // 0-100
        uint256 totalExposure,  // total LP funds at risk (wei)
        uint256 timestamp
    );

    // ── State 
    address public owner;
    uint256 public riskThreshold = 70; // trigger if score >= 70

    struct PoolMetrics {
        uint256 priceDeviation;   // % price drop scaled by 100
        uint256 volumeSpike;      // volume multiplier scaled by 100
        uint256 lastUpdated;
    }

    mapping(address => PoolMetrics) public poolMetrics;

    // ── Modifiers 
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // ── Constructor 
    constructor() {
        owner = msg.sender;
    }

    // ── Core Functions 

    /**
     * @notice Update risk metrics for a pool and
     *         automatically emit InsuranceEvent if
     *         risk score crosses the threshold.
     * @param pool            Address of the Uniswap pool
     * @param priceDeviation  Price drop % scaled by 100 (e.g. 3000 = 30%)
     * @param volumeSpike     Volume multiplier scaled by 100 (e.g. 500 = 5x)
     * @param totalExposure   Total LP value at risk in wei
     */
    function updateRiskMetrics(
        address pool,
        uint256 priceDeviation,
        uint256 volumeSpike,
        uint256 totalExposure
    ) external onlyOwner {
        poolMetrics[pool] = PoolMetrics({
            priceDeviation: priceDeviation,
            volumeSpike:    volumeSpike,
            lastUpdated:    block.timestamp
        });

        uint256 score = computeRiskScore(priceDeviation, volumeSpike);

        if (score >= riskThreshold) {
            emit InsuranceEvent(pool, score, totalExposure, block.timestamp);
        }
    }

    /**
     * @notice Manually trigger an insurance event (for testing / demo)
     */
    function triggerInsuranceEvent(
        address pool,
        uint256 riskScore,
        uint256 totalExposure
    ) external onlyOwner {
        emit InsuranceEvent(pool, riskScore, totalExposure, block.timestamp);
    }

    /**
     * @notice Compute a 0-100 risk score from metrics.
     *         This is the lightweight on-chain "AI" scoring model.
     *         Weighted sum: 60% price deviation + 40% volume spike
     */
    function computeRiskScore(
        uint256 priceDeviation,
        uint256 volumeSpike
    ) public pure returns (uint256) {
        // Normalise: max expected priceDeviation = 5000 (50%)
        //            max expected volumeSpike     = 1000 (10x)
        uint256 priceScore  = (priceDeviation * 60) / 5000;
        uint256 volumeScore = (volumeSpike    * 40) / 1000;

        uint256 total = priceScore + volumeScore;
        return total > 100 ? 100 : total;
    }

    // ── Admin ─────────────────────────────────────────────────
    function setRiskThreshold(uint256 threshold) external onlyOwner {
        require(threshold <= 100, "Invalid threshold");
        riskThreshold = threshold;
    }
}