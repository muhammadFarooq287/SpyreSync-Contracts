// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
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
    CountersUpgradeable.Counter public _itemIds;
    CountersUpgradeable.Counter public _itemsSold;
    CountersUpgradeable.Counter public _collectionIds;
    // ***nft buyer case****//
    mapping(uint=>bool) public nftstate;
    mapping(uint=>address) public nftbuyerAddress;
    mapping(uint256 => uint256) public nftBuyerReturns;

    //NFT Auction properties
    event AuctionEnded(address winner, uint amount);
    //NFT Auction structures
    struct Auction {
        address  highestBidder;
        uint256 highestBid;
        uint auctionEndTime;
        bool OpenForBidding;
        uint256 tokenId;
    }
    // NFT Auctions
    mapping (uint256 => Auction) public auctions;

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


    function initialize(address _marketplaceOwner) public initializer {
        __ERC721_init("sellItMarket", "SIM");
        __Ownable_init();
        __UUPSUpgradeable_init();
        marketplaceOwner=_marketplaceOwner;
        setServiceFeePercentage(5);
    }

    
    function getUserCollections(address userAddress) public view returns(uint256[] memory){
    return userCollections[userAddress];
    }

    function createANewCollection(string calldata _logoUrl,string calldata _collectionName,string calldata _category,string calldata _websiteUrl,string calldata _instaProfile) external {
    _collectionIds.increment();
    uint256 collectionId = _collectionIds.current();
    
    collections[collectionId] = Collection({
        userAddress:msg.sender,
        collectionId:collectionId,
        name:_collectionName,
        logoUrl:_logoUrl,
        category:_category,
        websiteUrl:_websiteUrl,
        instaProfileUrl:_instaProfile,
        itemsListed:0,
        itemsSold:0,
        totalSale:0
    });

    userCollections[msg.sender].push(collectionId);
    }

    function editCollection(uint256 collectionId,string calldata _logoUrl,string calldata _collectionName,string calldata _category,string calldata _websiteUrl,string calldata _instaProfile) external 
    {
    require(collections[collectionId].collectionId!=0,"Invalid collection id");
    require(collections[collectionId].userAddress==msg.sender,"You are not authorized for this operation");
    

    collections[collectionId].name = _collectionName;
    collections[collectionId].logoUrl = _logoUrl;
    collections[collectionId].category = _category;
    collections[collectionId].websiteUrl = _websiteUrl;
    collections[collectionId].instaProfileUrl = _instaProfile;
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
    function safeMint(address to, string memory uri) public {
        uint256 tokenId = _tokenIdCounter.current();
         require(to==msg.sender,"Address mismatch");
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }
        
   //******* NFT START **********//
     // NftAuction Code start here

    function startAuction(uint _biddingendtime , uint256 tokenId) public 
    {
        require(nftstate[tokenId]==false,"Already Buy in Process");
        require(msg.sender==ownerOf(tokenId),"Only owner can call this method");   
        auctions[tokenId].auctionEndTime = block.timestamp + _biddingendtime; 
        auctions[tokenId].tokenId = tokenId;  
        auctions[tokenId].OpenForBidding=true;
    }

// bidding and return pendings//
        function bid( uint256 tokenId) payable public{
        require(auctions[tokenId].OpenForBidding,"Bidding is not open yet");
        require(ownerOf(tokenId)!=msg.sender,"Owner cannot bid");
        require(msg.value >= 1 ether,"Price can't be less than 1 Ether");
        address  currentBidOwner = auctions[tokenId].highestBidder;
        uint256  currentBidAmount = auctions[tokenId].highestBid;
        if(block.timestamp > auctions[tokenId].auctionEndTime){
            revert("The auction has already ended");
        }
        if(msg.value <=  currentBidAmount) {
            revert("There is already higher or equal bid exist");
        }
        if(msg.value > currentBidAmount ) {
            payable(currentBidOwner).transfer(currentBidAmount);
        }
          auctions[tokenId].highestBidder =  msg.sender;
        auctions[tokenId].highestBid =  msg.value;
    }

    // *****Payment and token transfer *****//
        function confirmbidding( uint256 tokenId) public{
            address seller=ownerOf(tokenId);
            require(auctions[tokenId].OpenForBidding,"Bidding is not open yet");
          require (block.timestamp > auctions[tokenId].auctionEndTime,"The auction has not ended yet");
          require (msg.sender == auctions[tokenId].highestBidder || msg.sender==marketplaceOwner,"Only HighestBidder can call this method");
          emit AuctionEnded(auctions[tokenId].highestBidder , auctions[tokenId].highestBid);
         uint256 serviceFee = calculateServiceFee(auctions[tokenId].highestBid);
         uint256 afterCutPrice = auctions[tokenId].highestBid - serviceFee ;
        _transfer(seller,auctions[tokenId].highestBidder,tokenId);     
        payable(marketplaceOwner).transfer(serviceFee);
        payable(seller).transfer(afterCutPrice);
         delete auctions[tokenId];
    }
    // ******Cancle Bidding and payment returns *****//
     function cancelbidding( uint256 tokenId) public
    { 
         require(auctions[tokenId].OpenForBidding,"Bidding is not open yet");
         require (block.timestamp > auctions[tokenId].auctionEndTime,"The auction has not ended yet");
          require (msg.sender == auctions[tokenId].highestBidder || msg.sender==marketplaceOwner,"Only HighestBidder can call this method");
        payable(auctions[tokenId].highestBidder).transfer(address(this).balance);
         delete auctions[tokenId];
    }
    // *****Buy NFTs in Marketplace *****//
   function buy(uint256 tokenId) public payable returns (bool) {
        if(auctions[tokenId].OpenForBidding){
            require((auctions[tokenId].highestBidder == address(0)) || (block.timestamp < auctions[tokenId].auctionEndTime),"Bidding in Process" );
           payable(auctions[tokenId].highestBidder).transfer(auctions[tokenId].highestBid);
          // end auction 
           delete auctions[tokenId];
        }
       require(nftstate[tokenId]==false,"Already in process");
        require (msg.value > 0 ether,"amount send is less than require value");    
        require (msg.sender != ownerOf(tokenId) ,"Only buyer can call this method"); 
         nftbuyerAddress[tokenId]=msg.sender;
        nftBuyerReturns[tokenId] = msg.value;
        nftstate[tokenId]=true;
          return true;
    }
    // ****Transfer the ownership of token and payment *******//
   function confirmDelivery(uint256 tokenId) external {
       
       require (nftstate[tokenId]==true,"ALREADY CANCLE ORDER"); 
         address  nftSeller=ownerOf(tokenId);
         address nftbuyer=nftbuyerAddress[tokenId];
         uint256 amount = nftBuyerReturns[tokenId];
          require (msg.sender == nftbuyer || msg.sender==marketplaceOwner,"Not buyer");
         require (msg.sender != ownerOf(tokenId) ,"Only buyer can call this method");
         uint256 serviceFee = calculateServiceFee(amount);
         uint256 afterCutPrice = amount - serviceFee;
         _transfer(nftSeller,nftbuyer,tokenId);
          payable(nftSeller).transfer(afterCutPrice);
        payable(marketplaceOwner).transfer(serviceFee);
          nftBuyerReturns[tokenId]=0;
          nftstate[tokenId]=false;
        
    }
     function cancelDelivery(uint256 tokenId) public
    { 
        require (nftstate[tokenId]==true,"ALREADY CONFIRMED ORDER");
          uint256 amount =  nftBuyerReturns[tokenId];
         address nftbuyer=nftbuyerAddress[tokenId];
         require (msg.sender == nftbuyer || msg.sender==marketplaceOwner,"Not buyer");
         payable(nftbuyer).transfer(amount);
         nftBuyerReturns[tokenId]=0;
         nftstate[tokenId]=false;
         
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }
    function _burn(uint256 tokenId) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
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
