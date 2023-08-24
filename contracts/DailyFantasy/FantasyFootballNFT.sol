// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


import "./NFT.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./FantasyFootballScores.sol";
import "../interfaces/IFantasyFootballNFT.sol";

contract FantasyFootballNFT is IFantasyFootballNFT, NFT {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public teamCounter;
    uint256 public prizePool;
    uint256 public towardPool;
    uint256 public rake;
    address public rakePool;
    uint256 public startDeadline;
    uint256 public round;
    uint256 public maxBudget; 
    mapping(uint256 => Team) public teams;
    mapping(uint256 => uint256) public teamRankings;
    mapping(uint256 => EnumerableSet.UintSet) private teamPlayerIds; // Player IDs for each team

    // uint8[9] public prizePercentages = [33, 20, 12, 10, 7, 6, 5, 4, 3];
    uint8[3] public prizePercentages = [50, 33, 17];
    uint256 public maxPlayersPerTeam;

    EnumerableSet.UintSet private rankedTeams;
    FantasyFootballScores public scoresContract;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        address _scoresContractAddress,
        address _rakePool,
        uint256 _maxPlayersPerTeam,
        uint256 _towardPool,
        uint256 _rake,
        uint256 _startDeadline,
        uint256 _round,
        uint256 _maxBudget 
    ) NFT(_name, _symbol, _uri) {

        scoresContract = FantasyFootballScores(_scoresContractAddress);
        teamCounter = 0;
        maxPlayersPerTeam = _maxPlayersPerTeam;
        prizePool = 0;
        towardPool = _towardPool;
        rake = _rake;
        rakePool = _rakePool;
        startDeadline = _startDeadline;
        round = _round;
        maxBudget = _maxBudget; 
    }

    function getTeam(uint256 teamId_) external view returns (Team memory){
        return teams[teamId_];
    }

    function createTeam(uint256[] memory _playerIds) external payable {
        require(block.timestamp < startDeadline, "Team creation deadline has passed");
        require(_playerIds.length == maxPlayersPerTeam, "Must select the correct number of players");
        require(msg.value == towardPool + rake, "Must send the correct ETH amount to create a team");
        require(getTotalPlayerCost(_playerIds) <= maxBudget, "Total player cost exceeds the maximum budget");

        uint256 tokenId = teamCounter;
        _mint(msg.sender, tokenId);

        teams[tokenId] = Team("", msg.sender, 0, 0);
        EnumerableSet.UintSet storage playersSet = teamPlayerIds[tokenId];

        for (uint256 i = 0; i < _playerIds.length; i++) {
            require(playersSet.add(_playerIds[i]), "Duplicate player IDs found");
        }

        prizePool += towardPool;
        payable(rakePool).transfer(rake);

        teamCounter++;
        emit TeamCreated(tokenId, msg.sender, _playerIds);
    }

    function calculateTeamTotalScore(uint256 _tokenId) internal view returns (uint256) {
        uint256[] memory playerIds = getPlayerIdsForTeam(_tokenId);
        uint256 totalScore = 0;

        for (uint256 i = 0; i < playerIds.length; i++) {
            uint256 playerScore = scoresContract.playerScores(round, playerIds[i]);
            totalScore += playerScore;
        }

        return totalScore;
    }

    // New function to get player IDs for a team
    function getPlayerIdsForTeam(uint256 _teamId) public view returns (uint256[] memory) {
        EnumerableSet.UintSet storage playersSet = teamPlayerIds[_teamId];
        uint256 length = playersSet.length();
        uint256[] memory playerIds = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            playerIds[i] = playersSet.at(i);
        }

        return playerIds;
    }


    function calculatePrizePerTeam(uint256 _tokenId) internal view returns (uint256) {

        // Calculate prize based on team ranking
        if (teamRankings[_tokenId] <= prizePercentages.length) {
            return prizePercentages[teamRankings[_tokenId] - 1] * prizePool / 100;
        } else {
            return 0; // Teams beyond the top 9 do not receive prizes
        }
    }

    function claimPrize(uint256 _tokenId) external {

        require(scoresContract.roundScoresUpdated(round), "Scores have not been updated for the round");
        require(ownerOf(_tokenId) == msg.sender, "Not the team owner");
        require(teams[_tokenId].prizeClaimed == 0, "Prize already claimed");

        // Calculate scores and rank teams only if it's the first claim
        if (rankedTeams.length() == 0) {
            calculateAndRankTeams();
        }

        uint256 prizePerTeam = calculatePrizePerTeam(_tokenId);
        teams[_tokenId].prizeClaimed = 1;
        if (prizePerTeam > 0) {
            payable(msg.sender).transfer(prizePerTeam);
            emit PrizeClaimed(_tokenId, prizePerTeam);
        }
    }

    function calculateAndRankTeams() internal {
        uint256 n = teamCounter;
        uint256[] memory scores = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            scores[i] = calculateTeamTotalScore(i);
            teams[i].score = scores[i];  // Store the score in the team struct too
        }

        // The start of the ranking code
        uint256[] memory sortedIndices = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            sortedIndices[i] = i;
        }

        // Sort indices based on scores using Bubble Sort (For simplicity, other efficient sorting algorithms can be used)
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (scores[sortedIndices[j]] < scores[sortedIndices[j + 1]]) {
                    // Swap
                    uint256 temp = sortedIndices[j];
                    sortedIndices[j] = sortedIndices[j + 1];
                    sortedIndices[j + 1] = temp;
                }
            }
        }

        uint ppLen = prizePercentages.length;
        // Assign ranks to each team based on sorted indices. Store rank only for top teams as per prizePercentages length
        for (uint256 i = 0; i < ppLen && i < n; i++) {
            teamRankings[sortedIndices[i]] = i + 1;
            rankedTeams.add(sortedIndices[i]);
        }
        // The end of the ranking code
    }


    
    function getTotalPlayerCost(uint256[] memory _playerIds) internal view returns (uint256) {
        uint256 totalCost = 0;
        for (uint256 i = 0; i < _playerIds.length; i++) {
            uint256 playerId = _playerIds[i];
            require(scoresContract.playerCosts(round, playerId) > 0, "Player cost not found");
            totalCost += scoresContract.playerCosts(round, playerId);
        }
        return totalCost;
    }


}
