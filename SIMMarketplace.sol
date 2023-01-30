// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

error PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error ItemNotForSale(address nftAddress, uint256 tokenId);
error NotListed(address _owner, uint _tokenId);
error AlreadyListed(address _owner, uint256 _tokenId);
error NoProceeds();
error NotOwner();
error NotApprovedForMarketplace();
error PriceMustBeAboveZero();
error AlreadyCreatedCollectionID();

contract SIMMarketplace is 
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    ERC721BurnableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIdCounter;
    address marketplaceOwner;
    uint256 public defaultServicefee;
    uint256[] public collectionIDs;
    uint256[] public allTokens;

    struct Collection {
      address userAddress;
      uint256 collectionId;
      string logoUrl;
      string name;
      string category;
      string websiteUrl;
      string instaProfileUrl;
      uint256 itemsListed;
      uint256 itemsSold;
      uint256 totalSale;
    }

    mapping(uint256=>Collection) public collections;
    mapping(address=>uint256[]) public userCollections;

    uint256 public listingFee = 25; //5%

    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private ownedTokens;

    mapping(address => mapping(uint256 => uint256)) private listingCollection;

    event ItemListed(
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemCancelled(
        address indexed seller,
        uint256 indexed tokenId
    );

    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

     // Function modifiers
   modifier isListed(address _owner, uint256 _tokenId, uint _price) {
        
        if (listingCollection[_owner][_tokenId] != _price) {
            revert NotListed(_owner, _tokenId);
        }
        _;
    }

   modifier notListed(
       address _owner,
       uint256 _tokenId,
       uint _price
   ) {
        if (listingCollection[_owner][_tokenId] == _price) {
            revert AlreadyListed(_owner, _tokenId);
        }
        _;
    }

    modifier isOwner(
        uint _collectionID,
        uint256 _tokenId,
        address _owner
    ) {
        if (ownedTokens[_owner][_collectionID] != _tokenId) {
            revert NotOwner();
        }
        _;
    }

    function initialize(address _marketplaceOwner) public initializer {
        __ERC721_init("sellItMarket", "SIM");
        __Ownable_init();
        __UUPSUpgradeable_init();
        marketplaceOwner=_marketplaceOwner;
        setServiceFeePercentage(5);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function setServiceFeePercentage(uint256 _newServiceFee) public  {
        require(_newServiceFee <= 100, " service fee will exceed salePrice");
        require( marketplaceOwner == msg.sender,"Only Marketplace Owner can call this method");
        defaultServicefee = _newServiceFee;
    }
    function calculateServiceFee(uint256 _salePrice) internal view returns (uint256) {
        require(defaultServicefee != 0,"Set Service fee first.");
        require(defaultServicefee <= 100, "ERC2981: service fee will exceed salePrice");
        uint256 servicefee = _salePrice.mul(defaultServicefee).div(100);
        return servicefee;
    }
    function safeMint(address to, string memory uri, uint _collectionID) public {
        uint256 tokenId = _tokenIdCounter.current();
        require(to==msg.sender,"Address mismatch");
        for(uint i=0; i<collectionIDs.length;i++)
        {
            if(_collectionID==collectionIDs[i])
            {
                revert AlreadyCreatedCollectionID();
            }
        }
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        ownedTokens[msg.sender][_collectionID] = tokenId;
        allTokens.push(tokenId);
    }

    function listItem(
        uint _collectionID,
        uint256 _tokenId,
        uint256 _price
    )
        external
        notListed(msg.sender, _tokenId, _price)
        isOwner( _collectionID, _tokenId, msg.sender)
    {
        if (_price <= 0) {
            revert PriceMustBeAboveZero();
        }
        listingCollection[msg.sender][_tokenId] = _price;
        emit ItemListed(msg.sender, _tokenId, _price);
    }

    function cancelListing(uint256 _collectionID, uint256 _tokenId, uint _price)
        external
        isOwner( _collectionID, _tokenId, msg.sender)
        isListed(msg.sender, _tokenId, _price)
    {
        delete (listingCollection[msg.sender][_tokenId]);
        emit ItemCancelled(msg.sender, _tokenId);
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }



}
