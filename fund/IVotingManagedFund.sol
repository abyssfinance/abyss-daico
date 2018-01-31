pragma solidity ^0.4.18;

/**
 * @title IVotingManagedFund
 * @dev Fund callbacks used by voting contracts
 */
interface IVotingManagedFund {
    /**
     * @dev TapVoting callback
     * @param agree True if new tap value is accepted by majority of contributors
     */
    function onTapVotingFinish(bool agree, uint256 _tap) public;
    /**
     * @dev BufferVoting callback
     * @param agree True if buffer amount is accepted by majority of contributors
     */
    function onBufferVotingFinish(bool agree, uint256 bufferAmount) public;
    /**
     * @dev OracleVoting callback
     * @param agree True if oracles decided to allow voting by contributors for refunding
     */
    function onOracleVotingFinish(bool agree) public;
    /**
     * @dev RefundVoting callback
     * @param agree True if contributors decided to allow refunding
     */
    function onRefundVotingFinish(bool agree) public;
}