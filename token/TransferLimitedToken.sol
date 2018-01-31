pragma solidity ^0.4.18;

import './ManagedToken.sol';

/**
 * @title TransferLimitedToken
 * @dev Token with ability to limit transfers within wallets included in limitedWallets list for certain period of time
 */
contract TransferLimitedToken is ManagedToken {
    mapping(address => bool) public limitedWallets;
    uint256 public constant limitTransfersPeriod = 365 days;
    uint256 public limitEndDate;
    address public limitedWalletsManager;
    bool public isLimitEnabled;

    /**
     * @dev TransferLimitedToken constructor
     * @param _limitStartDate Limit start date
     * @param _listener Token listener(address can be 0x0)
     * @param _owners Owners list
     * @param _limitedWalletsManager Address used to add/del wallets from limitedWallets
     */
    function TransferLimitedToken(uint256 _limitStartDate, address _listener, address[] _owners, address _limitedWalletsManager) public
        ManagedToken(_listener, _owners)
    {
        limitEndDate = _limitStartDate + limitTransfersPeriod;
        isLimitEnabled = true;
        limitedWalletsManager = _limitedWalletsManager;
    }

    /**
     * @dev Add address to limitedWallets
     * @dev Can be called only by manager
     */
    function addLimitedWalletAddress(address _wallet) public {
        require(msg.sender == limitedWalletsManager);
        limitedWallets[_wallet] = true;
    }

    /**
     * @dev Del address from limitedWallets
     * @dev Can be called only by manager
     */
    function delLimitedWalletAddress(address _wallet) public {
        require(msg.sender == limitedWalletsManager);
        limitedWallets[_wallet] = false;
    }

    /**
     * @dev Enable/disable transfer limit manually. Can be called only by manager
     */
    function setLimitState(bool _isLimitEnabled) public {
        require(msg.sender == limitedWalletsManager);
        isLimitEnabled = _isLimitEnabled;
    }

    /**
     * @dev Check if transfer between addresses is available
     * @param _from From address
     * @param _to To address
     * @return True if transfer is available else false
     */
    function canTransfer(address _from, address _to) public view returns(bool) {
        if(now >= limitEndDate || !isLimitEnabled) {
            return true;
        }
        if(!limitedWallets[_from] && !limitedWallets[_to]) {
            return true;
        }
        return false;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(canTransfer(msg.sender, _to));
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(canTransfer(_from, _to));
        return super.transferFrom(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        require(canTransfer(msg.sender, _spender));
        return super.approve(_spender,_value);
    }
}