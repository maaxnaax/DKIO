// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IFantasyFootballNFT {

    struct Team {
        string name;
        address owner;
        uint256 score;
        uint256 prizeClaimed;
    }

    event TeamCreated(uint256 indexed teamId, address indexed owner, uint256[] playerIds);
    event ScoreUpdated(uint256 indexed teamId, uint256 score);
    event PrizeClaimed(uint256 indexed teamId, uint256 prizeAmount);

    function teamCounter() external view returns (uint256);
    function prizePool() external view returns (uint256);
    function towardPool() external view returns (uint256);
    function rake() external view returns (uint256);
    function rakePool() external view returns (address);
    function startDeadline() external view returns (uint256);
    function round() external view returns (uint256);
    function maxBudget() external view returns (uint256);
    function teamRankings(uint256 _id) external view returns (uint256);
    function prizePercentages(uint256 _index) external view returns (uint8);
    function maxPlayersPerTeam() external view returns (uint256);

    function getTeam(uint256 teamId_) external view returns (Team memory);
    function createTeam(uint256[] memory _playerIds) external payable;
    function getPlayerIdsForTeam(uint256 _teamId) external view returns (uint256[] memory);
    function claimPrize(uint256 _tokenId) external;
}
