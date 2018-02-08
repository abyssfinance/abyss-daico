pragma solidity ^0.4.18;

import '../ownership/MultiOwnable.sol';
import './ERC20Token.sol';
import './ITokenEventListener.sol';

/**
 * @title ManagedToken
 * @dev ERC20 compatible token with issue and destroy facilities
 * @dev All transfers can be monitored by token event listener
 */
contract ManagedToken is ERC20Token, MultiOwnable {
    bool public allowTransfers = false;
    bool public issuanceFinished = false;

    ITokenEventListener public eventListener;

    event AllowTransfersChanged(bool _newState);
    event Issue(address indexed _to, uint256 _value);
    event Destroy(address indexed _from, uint256 _value);
    event IssuanceFinished();

    modifier transfersAllowed() {
        assert(allowTransfers);
        _;
    }

    modifier canIssue() {
        assert(!issuanceFinished);
        _;
    }

    /**
     * @dev ManagedToken constructor
     * @param _listener Token listener(address can be 0x0)
     * @param _owners Owners list
     */
    function ManagedToken(address _listener, address[] _owners) public {
        if(_listener != address(0)) {
            eventListener = ITokenEventListener(_listener);
        }
        _setOwners(_owners);
    }

    /**
     * @dev Enable/disable token transfers. Can be called only by owners
     * @param _allowTransfers True - allow False - disable
     */
    function setAllowTransfers(bool _allowTransfers) external onlyOwner {
        allowTransfers = _allowTransfers;
        AllowTransfersChanged(_allowTransfers);
    }

    /**
     * @dev Set/remove token event listener
     * @param _listener Listener address (Contract must implement ITokenEventListener interface)
     */
    function setListener(address _listener) public onlyOwner {
        if(_listener != address(0)) {
            eventListener = ITokenEventListener(_listener);
        } else {
            delete eventListener;
        }
    }

    function transfer(address _to, uint256 _value) public transfersAllowed returns (bool) {
        bool success = super.transfer(_to, _value);
        if(hasListener() && success) {
            eventListener.onTokenTransfer(msg.sender, _to, _value);
        }
        return success;
    }

    function transferFrom(address _from, address _to, uint256 _value) public transfersAllowed returns (bool) {
        bool success = super.transferFrom(_from, _to, _value);
        if(hasListener() && success) {
            eventListener.onTokenTransfer(_from, _to, _value);
        }
        return success;
    }

    function hasListener() internal view returns(bool) {
        if(eventListener == address(0)) {
            return false;
        }
        return true;
    }

    /**
     * @dev Issue tokens to specified wallet
     * @param _to Wallet address
     * @param _value Amount of tokens
     */
    function issue(address _to, uint256 _value) external onlyOwner canIssue {
        totalSupply = safeAdd(totalSupply, _value);
        balances[_to] = safeAdd(balances[_to], _value);
        Issue(_to, _value);
        Transfer(address(0), _to, _value);
    }

    /**
     * @dev Destroy tokens on specified address (Called by owner or token holder)
     * @dev Fund contract address must be in the list of owners to burn token during refund
     * @param _from Wallet address
     * @param _value Amount of tokens to destroy
     */
    function destroy(address _from, uint256 _value) external {
        require(ownerByAddress[msg.sender] || msg.sender == _from);
        require(balances[_from] >= _value);
        totalSupply = safeSub(totalSupply, _value);
        balances[_from] = safeSub(balances[_from], _value);
        Destroy(_from, _value);
    }

    /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     *
     * approve should be called when allowed[_spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From OpenZeppelin StandardToken.sol
     * @param _spender The address which will spend the funds.
     * @param _addedValue The amount of tokens to increase the allowance by.
     */
    function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
        allowed[msg.sender][_spender] = safeAdd(allowed[msg.sender][_spender], _addedValue);
        Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     *
     * approve should be called when allowed[_spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From OpenZeppelin StandardToken.sol
     * @param _spender The address which will spend the funds.
     * @param _subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = safeSub(oldValue, _subtractedValue);
        }
        Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    /**
     * @dev Finish token issuance
     * @return True if success
     */
    function finishIssuance() public onlyOwner returns (bool) {
        issuanceFinished = true;
        IssuanceFinished();
        return true;
    }
}
