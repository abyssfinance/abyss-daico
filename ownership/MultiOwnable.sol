pragma solidity ^0.4.18;


/**
 * @title MultiOwnable
 * @dev The MultiOwnable contract has owners addresses and provides basic authorization control
 * functions, this simplifies the implementation of "users permissions".
 */
contract MultiOwnable {
    address public manager; // address used to set owners
    address[] owners;
    mapping(address => bool) public ownerByAddress;

    modifier onlyOwner() {
        require(ownerByAddress[msg.sender] == true);
        _;
    }

    /**
     * @dev MultiOwnable constructor sets the manager
     */
    function MultiOwnable() public {
        manager = msg.sender;
    }

    /**
     * @dev Function to set owners addresses
     */
    function setOwners(address[] _owners) public {
        require(msg.sender == manager);
        _setOwners(_owners);
    }

    function _setOwners(address[] _owners) internal {
        if(owners.length > 0) {
            for(uint256 i = 0; i < owners.length; i++) {
                ownerByAddress[owners[i]] = false;
            }
        }

        for(uint256 j = 0; j < _owners.length; j++) {
            ownerByAddress[_owners[j]] = true;
        }
        owners = _owners;
    }

    function getOwners() public constant returns (address[]) {
        return owners;
    }
}