pragma solidity ^0.4.18;

import '../math/SafeMath.sol';
import '../token/IERC20Token.sol';


/**
 * @title BaseVoting
 * @dev Abstract base class for voting contracts
 */
contract BaseVoting is SafeMath {
    struct Vote {
        uint256 time;
        uint256 weight;
        bool agree;
    }

    uint256 public constant MAX_TOKENS_WEIGHT_DENOM = 1000;

    IERC20Token public token;
    address public fundAddress;

    uint256 public startTime;
    uint256 public endTime;

    uint256 public yesCounter = 0;
    uint256 public noCounter = 0;
    uint256 public totalVoted = 0;
    uint256 public minTokensPerc = 0;

    bool public finalized;
    mapping(address => Vote) public votesByAddress;

    modifier checkTime() {
        require(now >= startTime && now <= endTime);
        _;
    }

    modifier notFinalized() {
        require(!finalized);
        _;
    }

    /**
     * @dev BaseVoting constructor
     * @param _tokenAddress ERC20 compatible token contract address
     * @param _fundAddress Fund contract address
     * @param _startTime Voting start time
     * @param _endTime Voting end time
     * @param _minTokensPerc - Min percent of tokens from totalSupply where voting is considered to be fulfilled
     */
    function BaseVoting(address _tokenAddress, address _fundAddress, uint256 _startTime, uint256 _endTime, uint256 _minTokensPerc) public {
        require(_tokenAddress != address(0));
        require(_startTime > now && _endTime > _startTime);

        token = IERC20Token(_tokenAddress);
        fundAddress = _fundAddress;
        startTime = _startTime;
        endTime = _endTime;
        minTokensPerc = _minTokensPerc;
        finalized = false;
    }

    /**
     * @dev Process user`s vote
     * @param agree True if user endorses the proposal else False
     */
    function vote(bool agree) public checkTime {
        require(votesByAddress[msg.sender].time == 0);

        uint256 voiceWeight = token.balanceOf(msg.sender);
        uint256 maxVoiceWeight = safeDiv(token.totalSupply(), MAX_TOKENS_WEIGHT_DENOM);
        voiceWeight =  voiceWeight <= maxVoiceWeight ? voiceWeight : maxVoiceWeight;

        if(agree) {
            yesCounter = safeAdd(yesCounter, voiceWeight);
        } else {
            noCounter = safeAdd(noCounter, voiceWeight);

        }

        votesByAddress[msg.sender].time = now;
        votesByAddress[msg.sender].weight = voiceWeight;
        votesByAddress[msg.sender].agree = agree;

        totalVoted = safeAdd(totalVoted, 1);
    }

    /**
     * @dev Revoke user`s vote
     */
    function revokeVote() public checkTime {
        require(votesByAddress[msg.sender].time > 0);

        uint256 voiceWeight = votesByAddress[msg.sender].weight;
        bool agree = votesByAddress[msg.sender].agree;

        votesByAddress[msg.sender].time = 0;
        votesByAddress[msg.sender].weight = 0;
        votesByAddress[msg.sender].agree = false;

        totalVoted = safeSub(totalVoted, 1);
        if(agree) {
            yesCounter = safeSub(yesCounter, voiceWeight);
        } else {
            noCounter = safeSub(noCounter, voiceWeight);
        }
    }

    /**
     * @dev Function is called after token transfer from user`s wallet to check and correct user`s vote
     *
     */
    function onTokenTransfer(address tokenHolder, uint256 amount) public {
        require(msg.sender == fundAddress);
        if(votesByAddress[tokenHolder].time == 0 || finalized || (now < startTime || now > endTime)) {
            return;
        }
        if(token.balanceOf(tokenHolder) >= votesByAddress[tokenHolder].weight) {
            return;
        }
        uint256 voiceWeight = amount;
        if(amount > votesByAddress[tokenHolder].weight) {
            voiceWeight = votesByAddress[tokenHolder].weight;
        }

        if(votesByAddress[tokenHolder].agree) {
            yesCounter = safeSub(yesCounter, voiceWeight);
        } else {
            noCounter = safeSub(noCounter, voiceWeight);
        }
        votesByAddress[tokenHolder].weight = safeSub(votesByAddress[tokenHolder].weight, voiceWeight);
    }

    /**
     * Finalize voting and call onVotingFinish callback with result
     */
    function tryToFinalize() public notFinalized returns(bool) {
        require(now >= endTime);
        finalized = true;
        onVotingFinish(isSubjectApproved());
        return true;
    }

    function isNowApproved() public view returns(bool) {
        return isSubjectApproved();
    }

    function getVotedTokensPerc() public view returns(uint256) {
        return safeDiv(safeMul(safeAdd(yesCounter, noCounter), 100), token.totalSupply());
    }

    function isSubjectApproved() internal view returns(bool) {
        uint256 votedTokensPerc = getVotedTokensPerc();

        if(votedTokensPerc >= minTokensPerc && yesCounter > noCounter) {
            return true;
        }
        return false;
    }

    /**
     * @dev callback called after voting finalization
     */
    function onVotingFinish(bool agree) internal;
}