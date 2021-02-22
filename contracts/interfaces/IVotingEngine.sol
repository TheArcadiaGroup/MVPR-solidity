pragma solidity 0.7.5;

interface IVotingEngine {
    function addVote(uint proposalType, uint256 proposalIndex) external;
}
