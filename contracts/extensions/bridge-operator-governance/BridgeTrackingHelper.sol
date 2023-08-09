// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract BridgeTrackingHelper {
  /// @dev Event emited when the bridge tracking contract tracks the invalid data, cause malform in sharing bridge reward.
  event BridgeTrackingIncorrectlyResponded();

  /**
   * @dev Internal function to validate the bridge tracking response for a given set of ballots.
   * @param totalBallot The total number of ballots available for the tracking response.
   * @param totalVote The total number of votes recorded in the tracking response.
   * @param ballots An array containing the individual ballot counts in the tracking response.
   * @return valid A boolean indicating whether the bridge tracking response is valid or not.
   * @notice The function checks if each individual ballot count is not greater than the total votes recorded.
   * @notice It also verifies that the sum of all individual ballot counts does not exceed the total available ballots.
   */
  function _isValidBridgeTrackingResponse(
    uint256 totalBallot,
    uint256 totalVote,
    uint256[] memory ballots
  ) internal pure returns (bool valid) {
    valid = true;
    uint256 sumBallot;
    uint256 length = ballots.length;

    unchecked {
      for (uint256 i; i < length; ++i) {
        if (ballots[i] > totalVote) {
          valid = false;
          break;
        }

        sumBallot += ballots[i];
      }
    }

    valid = valid && (sumBallot <= totalBallot);
  }
}
