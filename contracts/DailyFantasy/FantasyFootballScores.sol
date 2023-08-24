// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FantasyFootballScores is Ownable {
    // Mapping of roundId to a mapping of player IDs to their scores and update status
    mapping(uint256 => mapping(uint256 => uint256)) public playerScores;

    // Mapping of roundId to a mapping of player IDs to their update status and costs
    mapping(uint256 => mapping(uint256 => uint256)) public playerCosts;

    // Mapping of round to bool. True if the scores for that round have been updated
    mapping(uint256 => bool) public roundScoresUpdated;

    // Mapping of round to array of player IDs
    mapping(uint256 => uint256[]) public roundPlayerIds;

    // Address allowed to update scores (an oracle or admin)
    address public updater;

    event PlayerScoresUpdated(uint256 indexed roundId, uint256[] playerIds, uint256[] scores);
    event PlayerCostsSet(uint256 indexed roundId, uint256[] playerIds, uint256[] costs);
    event UpdaterChanged(address newUpdater);

    modifier onlyUpdater() {
        require(msg.sender == updater, "Only the updater can call this function");
        _;
    }

    constructor() {
        updater = msg.sender;
    }

    function setUpdater(address _newUpdater) external onlyOwner {
        updater = _newUpdater;
        emit UpdaterChanged(_newUpdater);
    }

    function updatePlayerScores(uint256 _roundId, uint256[] calldata _playerIds, uint256[] calldata _scores) external onlyUpdater {
        require(_playerIds.length == _scores.length , "Arrays length mismatch");

        for (uint256 i = 0; i < _playerIds.length; i++) {
            playerScores[_roundId][_playerIds[i]] = _scores[i];

            if (!contains(roundPlayerIds[_roundId], _playerIds[i])) {
                roundPlayerIds[_roundId].push(_playerIds[i]);
            }
        }

        roundScoresUpdated[_roundId] = true;
        emit PlayerScoresUpdated(_roundId, _playerIds, _scores);
    }

    // New function to set player costs for a specific round
    function setRound(uint256 _roundId, uint256[] calldata _playerIds, uint256[] calldata _costs) external onlyOwner {
        require(_playerIds.length == _costs.length, "Arrays length mismatch");

        for (uint256 i = 0; i < _playerIds.length; i++) {
            playerCosts[_roundId][_playerIds[i]] = _costs[i]; // Set player costs

            if (!contains(roundPlayerIds[_roundId], _playerIds[i])) {
                roundPlayerIds[_roundId].push(_playerIds[i]);
            }
        }
        emit PlayerCostsSet(_roundId, _playerIds, _costs);
    }

    // New function to get player info for a specific round
    function getPlayerInfoForRound(uint256 _roundId) external view returns (uint256[] memory, uint256[] memory, uint256[] memory) {
        uint256[] memory playerIds = roundPlayerIds[_roundId];
        uint256[] memory scores = new uint256[](playerIds.length);
        uint256[] memory costs = new uint256[](playerIds.length);

        for (uint256 i = 0; i < playerIds.length; i++) {
            scores[i] = playerScores[_roundId][playerIds[i]];
            costs[i] = playerCosts[_roundId][playerIds[i]];
        }

        return (playerIds, scores, costs);
    }

    // Utility function to check if an element exists in an array
    function contains(uint256[] storage arrayRef, uint256 element) internal view returns (bool) {
        for (uint256 i = 0; i < arrayRef.length; i++) {
            if (arrayRef[i] == element) {
                return true;
            }
        }
        return false;
    }
}
