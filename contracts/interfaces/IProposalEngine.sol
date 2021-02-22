pragma solidity 0.7.5;

interface IProposalEngine {
    function getVoteConfiguration(uint256 proposalType, uint256 proposalIndex)
        external
        view
        returns (
            uint256 memberQuorum,
            uint256 reputationQuorum,
            uint256 threshold,
            uint256 timeout,
            uint256 voterStakingLimit
        );

    function getProposalStatus(uint256 proposalType, uint256 proposalIndex)
        external
        returns (uint256);

    function getProposalCreationDate(
        uint256 proposalType,
        uint256 proposalIndex
    ) external view returns (uint256);
}
