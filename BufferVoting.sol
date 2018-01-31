pragma solidity ^0.4.18;

import './voting/BaseVoting.sol';
import './fund/IVotingManagedFund.sol';


/**
 * @title BufferVoting
 * @dev Voting to set overhead buffer amount
 */
contract BufferVoting is BaseVoting {
    uint256 public bufferAmount;

    /**
     * BufferVoting constructor
     * @param _bufferAmount Overhead buffer amount
     * @param _tokenAddress ERC20 compatible token contract address
     * @param _fundAddress Fund contract address
     * @param _startTime Voting start time
     * @param _endTime Voting end time
     * @param _minTokensPerc - Min percent of tokens from totalSupply where voting is considered to be fulfilled
     */
    function BufferVoting(uint256 _bufferAmount, address _tokenAddress, address _fundAddress, uint256 _startTime, uint256 _endTime, uint256 _minTokensPerc) public
        BaseVoting(_tokenAddress, _fundAddress, _startTime, _endTime, _minTokensPerc)
    {
        bufferAmount = _bufferAmount;
    }

    function onVotingFinish(bool agree) internal {
        IVotingManagedFund fund = IVotingManagedFund(fundAddress);
        fund.onBufferVotingFinish(agree, bufferAmount);
    }
}
