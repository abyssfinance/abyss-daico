pragma solidity ^0.4.18;

/**
 * @title ITokenEventListener
 * @dev Interface which should be implemented by token listener
 */
interface ITokenEventListener {
    /**
     * @dev Function is called after token transfer/transferFrom
     * @param _from Sender address
     * @param _to Receiver address
     * @param _value Amount of tokens
     */
    function onTokenTransfer(address _from, address _to, uint256 _value) public;
}