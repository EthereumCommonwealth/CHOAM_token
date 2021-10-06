// SPDX-License-Identifier: No License (None)
pragma solidity ^0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        _owner = msg.sender; // FOR TEST ONLY!!! In the release version will be assigned owner address
        //_owner = 0x82C806a6cB2A9B055C69c1860D968A9F932477df;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    /*
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    */

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

interface IERC223 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
}


interface IERC223Recipient { 
/**
 * @dev Standard ERC223 function that will handle incoming token transfers.
 *
 * @param _from  Token sender address.
 * @param _value Amount of tokens.
 * @param _data  Transaction metadata.
 */
    function tokenReceived(address _from, uint _value, bytes memory _data) external;
}

contract STO is IERC223Recipient, Ownable, ReentrancyGuard {

    uint256 public ST_USD;      // price of 1 Security Token in USD (18 decimals)
    uint256 public CLO_USD;     // price of 1 CLO in USD (18 decimals)
    uint256 public CLOE_USD;    // price of 1 CLOE in USD (18 decimals)
    uint256 public CLOE_CLO;    // price of 1 CLOE in CLO (18 decimals). May be used in UI.

    address public system;   // system wallet can change CLO and CLOE price
    address payable public bank;    // receiver of CLO and CLOE
    IERC223 public tokenST; // Security token contract address
    IERC223 public tokenCLOE = IERC223(0x1eAa43544dAa399b87EEcFcC6Fa579D5ea4A6187); // CLOE token contract address
    
    event SetSystem(address _system);
    event SetBank(address _bank);
    event SetPrice(uint256 priceCLO, uint256 priceCLOE);
    event SetPriceST(uint256 priceST);


    modifier onlyOwnerOrSystem() {
        require(system == msg.sender || owner() == msg.sender, "Ownable: caller is not the owner or system");
        _;
    }

    constructor (address _tokenST) {
        tokenST = IERC223(_tokenST);
        system = 0xf9e7D15E0aEfd6Dd2D7e4CF3A3611d3209457067;
        bank = payable(msg.sender); // FOR TEST ONLY!!! In the release version will be assigned bank address
        emit SetSystem(system);
        emit SetBank(bank);
    }
    
    function tokenReceived(address _from, uint _value, bytes memory _data) external override onlyOwner {
        require(msg.sender == address(tokenST), "Do not allow any token deposits other than STO token");
        //require(_from == owner(), "Only owner can deposit STO tokens");
        
        IERC223(msg.sender).increaseAllowance(address(this), _value);
    }

    function setSystem(address _system) onlyOwner external
    {
        system = _system;
        emit SetSystem(_system);
    }

    function setBank(address payable _bank) onlyOwner external
    {
        require(_bank != address(0), "Zero address not allowed");
        bank = _bank;
        emit SetBank(_bank);
    }

    // If someone accidentally transfer tokens to this contract, the owner will be able to rescue it and refund sender.
    function rescueTokens(address _token) external onlyOwner {
        if (address(0) == _token) {
            payable(msg.sender).transfer(address(this).balance);
        } else {
            uint256 available = IERC223(_token).balanceOf(address(this));
            IERC223(_token).transfer(msg.sender, available);
        }
    }

    function setPrice(uint256 priceCLO, uint256 priceCLOE) onlyOwnerOrSystem external {
        require(priceCLO != 0 && priceCLOE != 0, "Price can't be 0");
        CLO_USD = priceCLO;
        CLOE_USD = priceCLOE;
        CLOE_CLO = priceCLOE * 1 ether / priceCLO;
        emit SetPrice(priceCLO, priceCLOE);
    }

    function setPriceST(uint256 priceST) onlyOwnerOrSystem external {
        require(priceST != 0, "Price can't be 0");
        ST_USD = priceST;
        emit SetPriceST(priceST);
    }

    function buyToken(uint256 amountCLOE) nonReentrant payable external {
        require(msg.value != 0, "No CLO sent");
        uint256 cloValue = msg.value * CLO_USD;
        uint256 cloeValue = amountCLOE * CLOE_USD;
        uint256 totalValue = cloValue + cloeValue;
        require(cloValue * 100 / totalValue >= 95, "Only 5% can be paid by CLOE");
        if (amountCLOE != 0) {
            tokenCLOE.transferFrom(msg.sender, bank, amountCLOE);
        }
        bank.transfer(msg.value);
        uint256 stAmount = totalValue / ST_USD;
        tokenST.transferFrom(address(this), msg.sender, stAmount);
    }
}
