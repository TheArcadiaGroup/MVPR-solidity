pragma solidity 0.7.5;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IReputation.sol";
import "./interfaces/IProposalEngine.sol";
import "hardhat/console.sol";

contract VotingEngine {
    using SafeMath for uint256;
    mapping(address => uint256) public committedRep;
    address public reputation;
    address public proposalEngine;

    enum VoteOutcome {Pass, Fail, Incomplete, CriteriaUnmet}
    // Map voter to proposalIndex to amountCommitted
    mapping(address => mapping(uint256 => uint256)) public stakedReps;
    struct Receipt {
        bool hasVoted;
        bool decision;
        uint256 votes;
    }
    struct VoteData {
        uint256 proposalIndex;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 membersCount;
        uint256 totalStaked;
        mapping(address => Receipt) voters;
        VoteOutcome outcome;
        uint256 proposalType;
    }

    mapping(uint256 => VoteData) public votes;
    uint256 public voteCount;
    event VoteSubmitted(
        address voter,
        uint256 voteIndex,
        uint256 repToStake,
        bool voteDirection
    );

    constructor(address _reputation, address _proposalEngine) public {
        reputation = _reputation;
        proposalEngine = _proposalEngine;
    }

    function addVote(uint256 proposalType, uint256 proposalIndex) external {
        require(msg.sender == proposalEngine);
        VoteData storage newVote = votes[voteCount++];
        newVote.proposalIndex = proposalIndex;
        newVote.proposalType = proposalType;
    }

    function submitTransitionVote(
        uint256 voteIndex,
        uint256 repToStake,
        bool voteDirection
    ) external {
        require(
            IReputation(reputation).isMember(msg.sender),
            "Only members can vote."
        );
        VoteData storage vote = votes[voteIndex];
        uint256 proposalIndex = vote.proposalIndex;
        uint256 proposalType = vote.proposalType;
        (
            uint256 memberQuorum,
            uint256 reputationQuorum,
            uint256 threshold,
            uint256 timeout,
            uint256 voterStakingLimit
        ) =
            IProposalEngine(proposalEngine).getVoteConfiguration(
                proposalType,
                proposalIndex
            );

        require(
            block.timestamp <=
                IProposalEngine(proposalEngine).getProposalCreationDate(
                    proposalType,
                    proposalIndex
                ) +
                    timeout *
                    1 days,
            "Vote no longer active."
        );
        require(
            IProposalEngine(proposalEngine).getProposalStatus(
                proposalType,
                    proposalIndex
            ) == 1,
            "Proposal is not in transition vote"
        );
        uint256 repBalance = IReputation(reputation).balanceOf(msg.sender);
        require(
            repBalance >= repToStake,
            "You can't commit more than your balance"
        );

        // require(repToStake <= repBalance.div(10000).mul(voterStakingLimit));
        // TO DO: PERCENTAGE
        require(
            repToStake <= repBalance.sub(committedRep[msg.sender]),
            "Already staked reputation in other active votes."
        );
        voteDirection == false
            ? vote.againstVotes = vote.againstVotes.add(repToStake)
            : vote.forVotes = vote.forVotes.add(repToStake);
        if (!vote.voters[msg.sender].hasVoted)
            vote.membersCount = vote.membersCount.add(1);

        vote.totalStaked = vote.totalStaked.add(repToStake);
        vote.voters[msg.sender].hasVoted = true;
        vote.voters[msg.sender].decision = voteDirection;
        vote.voters[msg.sender].votes = vote.voters[msg.sender].votes.add(
            repToStake
        );
        emit VoteSubmitted(msg.sender, voteIndex, repToStake, voteDirection);
    }

    // function castFullVote() {

    // }

    function calculateVote(uint256 voteIndex) external returns (VoteOutcome) {
        VoteData storage vote = votes[voteIndex];
        uint256 proposalIndex = vote.proposalIndex;
        uint256 proposalType = vote.proposalType;
        (
            uint256 memberQuorum,
            uint256 reputationQuorum,
            uint256 threshold,
            uint256 timeout,
            uint256 voterStakingLimit
        ) =
            IProposalEngine(proposalEngine).getVoteConfiguration(
                proposalType,
                proposalIndex
            );
        require(
            block.timestamp >
                IProposalEngine(proposalEngine).getProposalCreationDate(
                    proposalType,
                    proposalIndex
                ) +
                    timeout *
                    1 minutes,
            "Vote is still active."
        );
        require(
            IProposalEngine(proposalEngine).getProposalStatus(
                proposalType,
                proposalIndex
            ) ==
                1 ||
                IProposalEngine(proposalEngine).getProposalStatus(
                    proposalType,
                    proposalIndex
                ) ==
                2,
            "Proposal needs to be in transition vote state or full vote."
        );
        VoteOutcome outcome = VoteOutcome.Incomplete;
        if (
            vote.membersCount < memberQuorum ||
            vote.totalStaked < reputationQuorum
        ) {
            console.log("criterai not met");
            vote.outcome = outcome;
            return outcome;
        }

        // All conditions are met; calculate votes
        uint256 totalVotes = vote.againstVotes.add(vote.forVotes);
        if (vote.againstVotes > vote.forVotes) {
            console.log("against votes ");
            vote.againstVotes.mul(uint256(10000)).div(totalVotes.mul(100)) >
                threshold
                ? outcome = VoteOutcome.Fail
                : outcome = VoteOutcome.CriteriaUnmet;
        } else if (vote.againstVotes < vote.forVotes) {
            console.log("for votes ");
            console.log(
                "vote.forVotes.mul(uint256(10000)).div(totalVotes.mul(100)) ",
                vote.forVotes.mul(uint256(10000)).div(totalVotes.mul(100))
            );
            vote.forVotes.mul(uint256(10000)).div(totalVotes.mul(100)) >
                threshold
                ? outcome = VoteOutcome.Pass
                : outcome = VoteOutcome.CriteriaUnmet;
        }
        // Reaching this statement means: FOR = AGAINST or threshold not met
        vote.outcome = outcome;
        if (outcome == VoteOutcome.Pass) {
            // Change status to full vote
        }
        return vote.outcome;
    }

    function unCommitRep(uint256 voteIndex) external {}
}
