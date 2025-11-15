// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SAMMFees
 * @notice Library for calculating dynamic fees in SAMM
 * @dev Ported from Rust implementation in fees.rs
 *
 * Fee Formula:
 * - Fees range from 1x to 5x the base fee
 * - Adaptive component based on trade impact
 * - Larger trades relative to pool size pay higher fees
 */
library SAMMFees {
    /**
     * @notice Calculate the dynamic fee for a SAMM swap
     * @param outputAmount The amount of tokens the user wants to receive
     * @param outputReserve The current reserve of the output token
     * @param inputReserve The current reserve of the input token
     * @param feeNumerator The base fee numerator
     * @param feeDenominator The fee denominator
     * @return fee The calculated fee amount in input tokens
     *
     * @dev Algorithm from fees.rs:47-78
     *
     * Formula:
     * max_fee_numerator = fee_numerator * 5
     * tmp = (output_amount * 12 / 10 * fee_denominator) / output_reserve
     *
     * if (tmp + fee_numerator > max_fee_numerator):
     *     // Use minimal fee (for large pools or small trades)
     *     fee = output_amount * fee_numerator * input_reserve / output_reserve / fee_denominator
     * else:
     *     // Use adaptive fee (for smaller pools or larger trades)
     *     fee = output_amount * (max_fee_numerator - tmp) * input_reserve / output_reserve / fee_denominator
     */
    function calculateFeeSAMM(
        uint256 outputAmount,
        uint256 outputReserve,
        uint256 inputReserve,
        uint256 feeNumerator,
        uint256 feeDenominator
    ) internal pure returns (uint256) {
        // Return 0 if fee is disabled or no output
        if (feeNumerator == 0 || outputAmount == 0) {
            return 0;
        }

        // Calculate max fee (5x base fee)
        uint256 maxFeeNumerator = feeNumerator * 5;

        // Calculate adaptive component
        // tmp = (output_amount * 12 / 10 * fee_denominator) / output_reserve
        // Reorder to avoid intermediate overflow: (output_amount * 12 * fee_denominator) / (10 * output_reserve)
        uint256 tmp = (outputAmount * 12 * feeDenominator) / (10 * outputReserve);

        // Check if we should use minimal fee
        if (tmp + feeNumerator > maxFeeNumerator) {
            // Minimal fee formula:
            // fee = output_amount * fee_numerator * input_reserve / output_reserve / fee_denominator
            uint256 fee = (outputAmount * feeNumerator * inputReserve) /
                          (outputReserve * feeDenominator);
            return fee;
        } else {
            // Adaptive fee formula:
            // fee = output_amount * (max_fee_numerator - tmp) * input_reserve / output_reserve / fee_denominator
            uint256 fee = (outputAmount * (maxFeeNumerator - tmp) * inputReserve) /
                          (outputReserve * feeDenominator);
            return fee;
        }
    }

    /**
     * @notice Calculate standard proportional fee (for traditional swaps)
     * @param tokenAmount The amount of tokens to calculate fee on
     * @param feeNumerator The fee numerator
     * @param feeDenominator The fee denominator
     * @return The calculated fee amount
     */
    function calculateFee(
        uint256 tokenAmount,
        uint256 feeNumerator,
        uint256 feeDenominator
    ) internal pure returns (uint256) {
        if (feeNumerator == 0 || tokenAmount == 0) {
            return 0;
        }

        uint256 fee = (tokenAmount * feeNumerator) / feeDenominator;

        // Minimum fee of 1 token if calculation rounds to 0
        if (fee == 0) {
            return 1;
        }

        return fee;
    }

    /**
     * @notice Calculate the owner's portion of trading fees
     * @param tradingTokens The amount of tokens being traded
     * @param ownerFeeNumerator The owner fee numerator
     * @param ownerFeeDenominator The owner fee denominator
     * @return The owner fee amount
     */
    function ownerTradingFee(
        uint256 tradingTokens,
        uint256 ownerFeeNumerator,
        uint256 ownerFeeDenominator
    ) internal pure returns (uint256) {
        return calculateFee(tradingTokens, ownerFeeNumerator, ownerFeeDenominator);
    }

    /**
     * @notice Calculate the host's portion of owner fees
     * @param ownerFee The owner fee amount
     * @param hostFeeNumerator The host fee numerator
     * @param hostFeeDenominator The host fee denominator
     * @return The host fee amount
     */
    function hostFee(
        uint256 ownerFee,
        uint256 hostFeeNumerator,
        uint256 hostFeeDenominator
    ) internal pure returns (uint256) {
        return calculateFee(ownerFee, hostFeeNumerator, hostFeeDenominator);
    }

    /**
     * @notice Validate that fee fractions are reasonable
     * @param numerator The fee numerator
     * @param denominator The fee denominator
     * @return true if valid, false otherwise
     */
    function validateFraction(uint256 numerator, uint256 denominator) internal pure returns (bool) {
        // Both zero is allowed (no fee)
        if (denominator == 0 && numerator == 0) {
            return true;
        }
        // Numerator must be less than denominator (fee < 100%)
        return numerator < denominator;
    }
}
