// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

pragma abicoder v2; // required to accept structs as function parameters

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
///import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
//import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Random.sol";

interface ILooxooryNft{

    function lazyMint(
        uint256 _tokenID,
        address _ownerAddress,
        address _artistAddress,
        uint256 _minPrice, 
        string memory  _uri,
        bytes memory _signature
        )
        external;

    function getCurrenttokenID()
        external
        view
        returns(uint256);
}

contract LooxooryNFTMarketplaceUpdated is
    ReentrancyGuard,
    Ownable,
    ERC721,
    ERC721URIStorage,
    EIP712 
{
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    Counters.Counter public _itemIds;
    Counters.Counter public _itemsSold;
    Counters.Counter public _campaignIds;

    string private constant SIGNING_DOMAIN = "LazyNFT-Voucher";
    string private constant SIGNATURE_VERSION = "1";

    address public randomContract;
    address public nftContract;
    address public voucherHolder;
    
    uint256 public totalSale;

    bool public isCurrentlyOnAuction;
    uint256 public currentlyOnAuction;
    uint256 public TOTAL_PERCENTAGE = 100;

    struct Bidder{
        address bidderAddress;
        uint256 bidderAmount;
    }

    struct NFTVoucher
    {
        uint256 tokenID;
        address ownerAddrress;
        uint256 minPrice;
        string uri;
        address royaltyAddress;

    /// @notice the EIP-712 signature of all other fields in the NFTVoucher struct. For a voucher to be valid, it must be signed by an account with the MINTER_ROLE.
        bytes signature;
    }

    /*struct LazyNFTVoucher {
        uint256 tokenId;
        uint256 price;
        string uri;
        address artist;
        bytes signature;
    }*/

    struct MarketItem {
        uint256 itemId;
        uint256 tokenID;
        uint256 price;
        bool sold;
        bool isOnAuction;
        uint256 bidEndTime;
        string metadataUrl;
        address artistAddress;
        bytes signature;
        uint256 platformFee;
        uint256 itemsSold;
        address owner;
        uint256 campaignID;
    }

    struct CreateMarketItemStruct {
        uint256 price;
        string metadataUrl;
        address artistAddress;
        uint256 platformFee;
        bytes signature;
    }

    struct CreateCampaignStruct{
      uint8[] tokenIDs;
      string winnerPrize;
      string[] winnerPrizeImages;
      string campaignDescription;
      uint256 maxNoOfParticipants;
      uint256 drawTime;
      string ngoName;
      string ngoImage;
      address ngoAddress;
    }

    struct Campaign {
        uint256 campaignID;
        address creatorAddress;
        uint8[] tokenIDs;
        uint256 totalVouchers;
        address winnerAddress;
        string winnerPrize;
        string[] winnerPrizeImages;
        string campaignDescription;
        uint256 maxNoOfParticipants;
        uint256 currentNoOfParticipants;
        uint256 drawTime;
        string ngoName;
        string ngoImage;
        address ngoAddress;
        bool isEnded;
        address[] participants;
        uint256 soldVouchers;
        bool donate;
    }

    mapping(uint256=>MarketItem) public nftItems;
    ///mapping(address => NFTVoucher) private ownedNFTVouchers;
    mapping(uint256=>Campaign) public campaigns;
    mapping(uint256=>Bidder) public bidderInfo;
    uint256 public totalAmountDue;
    uint8[] private filteredNfts;

    event ItemCreated(
        uint256 tokenID,
        uint256 price,
        bool sold,
        bool isOnAuction,
        uint256 bidEndTime,
        address artistAddress,
        uint256 platformFee,
        address owner
    );

    event CampaignCreated(
        uint256 campaignID,
        address creatorAddress,
        uint8[] nfts,
        address winnerAddress,
        string winnerPrize,
        string[] winnerPrizeImages,
        string campaignDescription,
        uint256 maxNoOfParticipants,
        uint256 currentNoOfParticipants,
        uint256 drawTime,
        string ngoName,
        string ngoImage,
        address ngoAddress
    );

    event ItemSold(
      uint256 itemId,
      uint256 tokenID,
      address seller,
      address buyer,
      uint256 price
    );

    event BidAdded(
      uint256 itemId,
      uint256 tokenID,
      address bidder,
      uint256 amount
    );

    event BidReturned(
      uint256 itemId,
      uint256 tokenID,
      address bidder,
      uint256 amount
    );

    constructor(
        address _nftContract,
        address _randomContract,
        address _voucherHolder)
        ERC721("LazyNFT", "LAZ") 
        EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION)
    {
        require(_nftContract!=address(0),"Invalid NFT Contract address");
        require(_randomContract!=address(0),"Invalid NFT Contract address");
        require(_voucherHolder!=address(0),"Invalid NFT Contract address");
        nftContract = _nftContract;
        randomContract = _randomContract;
        voucherHolder = _voucherHolder;
    }

    function setNftContract(
        address _nftContract)
        public
        onlyOwner
    {
        require(_nftContract!=address(0),"Invalid NFT Contract address");
        nftContract = _nftContract;
    }

    function setRandomContract(
        address _randomContract)
        public
        onlyOwner
    {
        require(_randomContract!=address(0),"Invalid Random Contract address");
        randomContract = _randomContract;
    }

    function setNFTHolder(
        address _voucherHolder)
        public
        onlyOwner
    {
        require(_voucherHolder!=address(0),"Invalid NFT Holder address");
        voucherHolder = _voucherHolder;
    }

    function createCampaign(
        CreateCampaignStruct memory _campaignDTO
        )
        public onlyOwner
    {

        require(_campaignDTO.drawTime>block.timestamp,"Invalid Draw time");
        _campaignIds.increment();
        uint256 currentCampaignId = _campaignIds.current();
        uint8[] memory emptyArr = new uint8[](0);
        filteredNfts = emptyArr;

        for(uint256 i=0;i<_campaignDTO.tokenIDs.length;i++)
        {
          if(nftItems[_campaignDTO.tokenIDs[i]].owner==voucherHolder
           && nftItems[_campaignDTO.tokenIDs[i]].campaignID==0
           && !nftItems[_campaignDTO.tokenIDs[i]].isOnAuction )
          {
            nftItems[_campaignDTO.tokenIDs[i]].campaignID = currentCampaignId;
            filteredNfts.push(_campaignDTO.tokenIDs[i]);
          }
        }

        address[] memory participants;

        campaigns[currentCampaignId] = Campaign
        (
            {
                campaignID:currentCampaignId,
                creatorAddress:msg.sender,
                winnerAddress:address(0),
                tokenIDs:filteredNfts,
                totalVouchers:filteredNfts.length,
                winnerPrize:_campaignDTO.winnerPrize,
                winnerPrizeImages:_campaignDTO.winnerPrizeImages,
                campaignDescription:_campaignDTO.campaignDescription,
                maxNoOfParticipants:_campaignDTO.maxNoOfParticipants,
                currentNoOfParticipants:0,
                drawTime:_campaignDTO.drawTime,
                ngoName:_campaignDTO.ngoName,
                ngoImage:_campaignDTO.ngoImage,
                ngoAddress: _campaignDTO.ngoAddress,
                isEnded:false,
                participants:participants,
                soldVouchers:0,
                donate:false
            }
        );

        /*emit CampaignCreated
        (
            currentCampaignId,
            msg.sender, 
            _campaignDTO.tokenIDs,
            address(0), 
            _campaignDTO.winnerPrize, 
            _campaignDTO.winnerPrizeImages, 
            _campaignDTO.campaignDescription, 
            _campaignDTO.maxNoOfParticipants, 
            0, 
            _campaignDTO.drawTime, 
            _campaignDTO.ngoName, 
            _campaignDTO.ngoImage,
            _campaignDTO.ngoAddress
        );*/
    }

    function createMarketItem(
        CreateMarketItemStruct memory marketItem
        )
        public
        onlyOwner
    {
        require(marketItem.platformFee>=5 && marketItem.platformFee<=50,"Invalid platform fee");
        _itemIds.increment();
        uint256 itemId = _itemIds.current();
        

        nftItems[itemId] = MarketItem ({
            itemId:itemId,
            tokenID:ILooxooryNft(nftContract).getCurrenttokenID(),
            price:marketItem.price,
            sold:false,
            isOnAuction:false,
            bidEndTime:0,
            metadataUrl:marketItem.metadataUrl,
            artistAddress:marketItem.artistAddress,
            signature: marketItem.signature,
            platformFee:marketItem.platformFee,
            itemsSold:0,
            owner:voucherHolder,
            campaignID:0
        });

        emit ItemCreated
        (
            ILooxooryNft(nftContract).getCurrenttokenID(), 
            marketItem.price, 
            false, 
            false, 
            0, 
            marketItem.artistAddress, 
            marketItem.platformFee, 
            voucherHolder
        );
    }

    function createMarketSale(
        uint256 itemId,
        uint256 amount,
        bool _donate
        )
        public
        payable
        nonReentrant
    {
        require(nftItems[itemId].campaignID!=0,"NFT is not in any campaign");
        require(amount>=1,"Invalid amount");
        require(campaigns[nftItems[itemId].campaignID].drawTime>=block.timestamp,"Draw time already completed");
        require(campaigns[nftItems[itemId].campaignID].currentNoOfParticipants<campaigns[nftItems[itemId].campaignID].maxNoOfParticipants,"Campaign already completed");

        require(!nftItems[itemId].isOnAuction,"Cannot buy directly");
        require(!nftItems[itemId].sold,"Already sold");
        require(msg.value == nftItems[itemId].price.mul(amount), "Please submit the asking price in order to complete the purchase");
        require(msg.sender!=nftItems[itemId].owner,"Already owned");
      
        campaigns[nftItems[itemId].campaignID].currentNoOfParticipants = campaigns[nftItems[itemId].campaignID].currentNoOfParticipants.add(1);
        campaigns[nftItems[itemId].campaignID].soldVouchers = campaigns[nftItems[itemId].campaignID].soldVouchers.add(1);
        campaigns[nftItems[itemId].campaignID].participants.push(msg.sender);
        _itemsSold.increment();
        totalSale = totalSale.add(nftItems[itemId].price.mul(amount));
  
        emit ItemSold(itemId, nftItems[itemId].tokenID, nftItems[itemId].owner , msg.sender, amount);
        ILooxooryNft(nftContract).lazyMint(
            nftItems[itemId].tokenID,
            voucherHolder,
            nftItems[itemId].artistAddress,
            nftItems[itemId].price,
            nftItems[itemId].metadataUrl,
            nftItems[itemId].signature);

        IERC721(nftContract).transferFrom(voucherHolder, msg.sender,nftItems[itemId].tokenID);
        
        uint256 platformFee = nftItems[itemId].price.mul(amount).mul(nftItems[itemId].platformFee).div(TOTAL_PERCENTAGE);
        uint256 artistShare = nftItems[itemId].price.mul(amount).sub(platformFee);
      
        payable(nftItems[itemId].artistAddress).transfer(artistShare);

        if (campaigns[nftItems[itemId].campaignID].donate == true)
        {
            IERC721(nftContract).transferFrom(msg.sender, (campaigns[nftItems[itemId].campaignID].ngoAddress),nftItems[itemId].tokenID);
        }
    }

    function listNftForAuction(
        uint256 nftID,
        uint256 bidEndTime)
        public
        onlyOwner
    {
        require(nftItems[nftID].tokenID!=0,"Invalid nft ID to auction");
        require(nftItems[nftID].campaignID==0,"nft already listed on a campaign");
        require(!nftItems[nftID].sold,"NFT is already sold");
        require(nftItems[nftID].owner==voucherHolder,"Cannot list this nft");
        require(!isCurrentlyOnAuction,"Another NFT is already on auction");
        require(bidEndTime>block.timestamp,"Invalid bid end time");

        isCurrentlyOnAuction = true;
        currentlyOnAuction = nftID;

        nftItems[nftID].isOnAuction = true;
        nftItems[nftID].bidEndTime = bidEndTime;
    }

    function createBidOnItem(
        uint256 itemId
        )
        public
        payable
        nonReentrant
    {  
        require(nftItems[itemId].isOnAuction,"Item is not on auction");
        require(nftItems[itemId].bidEndTime>block.timestamp,"Auction time ended");
        require(!nftItems[itemId].sold,"Already sold");
        require(msg.sender!=nftItems[itemId].owner,"Already owned");
        require(msg.value >= nftItems[itemId].price && msg.value > bidderInfo[itemId].bidderAmount, "Bid price must be greater than base price and highest bid");

        if(bidderInfo[itemId].bidderAddress!=address(0))
        {
            payable(bidderInfo[itemId].bidderAddress).transfer(bidderInfo[itemId].bidderAmount);
            totalAmountDue = totalAmountDue.sub(bidderInfo[itemId].bidderAmount);
            emit BidReturned(itemId, nftItems[itemId].tokenID, bidderInfo[itemId].bidderAddress, bidderInfo[itemId].bidderAmount);(itemId, nftItems[itemId].tokenID, msg.sender, msg.value);
        }
        totalAmountDue = totalAmountDue.add(msg.value);
        bidderInfo[itemId].bidderAddress = msg.sender;
        bidderInfo[itemId].bidderAmount = msg.value;

        emit BidAdded(itemId, nftItems[itemId].tokenID, msg.sender, msg.value);
    }

    function RedeemBidItem(
        uint256 itemId)
        public
        nonReentrant
    {
        require(nftItems[itemId].isOnAuction,"Item is not on auction");
        require(nftItems[itemId].bidEndTime<=block.timestamp,"Bidding is still in progress");

        require(msg.sender!=nftItems[itemId].owner,"Already owned");
        require(bidderInfo[itemId].bidderAddress==msg.sender,"Only highest bidder can claim the NFT");
    
    
        _itemsSold.increment();
        totalSale = totalSale.add(bidderInfo[itemId].bidderAmount);

        totalAmountDue = totalAmountDue.sub(bidderInfo[itemId].bidderAmount);

        ILooxooryNft(nftContract).lazyMint(
            nftItems[itemId].tokenID,
            voucherHolder,
            nftItems[itemId].artistAddress,
            nftItems[itemId].price,
            nftItems[itemId].metadataUrl,
            nftItems[itemId].signature);
        IERC721(nftContract).transferFrom(voucherHolder, msg.sender,nftItems[itemId].tokenID);
        

        uint256 platformFee = bidderInfo[itemId].bidderAmount.mul(nftItems[itemId].platformFee).div(TOTAL_PERCENTAGE);
        uint256 artistShare = bidderInfo[itemId].bidderAmount.sub(platformFee);
    
        payable(nftItems[itemId].artistAddress).transfer(artistShare);

        nftItems[itemId].sold = true;

        if(currentlyOnAuction == itemId)
        {
            isCurrentlyOnAuction = false;
            currentlyOnAuction = 0;
        }
    }

    function redeemVoucher(
        uint256 _itemId)
        public
        nonReentrant
    {
        require(!nftItems[_itemId].isOnAuction,"Item is on auction");
        require(msg.sender!=nftItems[_itemId].owner,"Already owned");
        require(!(nftItems[_itemId].campaignID!=0),"NFT is in campaign");

        _itemsSold.increment();

        ILooxooryNft(nftContract).lazyMint(
            nftItems[_itemId].tokenID,
            voucherHolder,
            nftItems[_itemId].artistAddress,
            nftItems[_itemId].price,
            nftItems[_itemId].metadataUrl,
            nftItems[_itemId].signature);
        IERC721(nftContract).transferFrom(voucherHolder, msg.sender,nftItems[_itemId].tokenID);

        uint256 platformFee = bidderInfo[_itemId].bidderAmount.mul(nftItems[_itemId].platformFee).div(TOTAL_PERCENTAGE);
        uint256 artistShare = bidderInfo[_itemId].bidderAmount.sub(platformFee);

        payable(nftItems[_itemId].artistAddress).transfer(artistShare);
        nftItems[_itemId].sold = true;

    }


    function resetAuction()
        public
        onlyOwner
    {
        require(isCurrentlyOnAuction,"No nft is on auction at this moment");
        require(nftItems[currentlyOnAuction].bidEndTime<block.timestamp,"Cannot reset now, bid time is not ended");

        if(bidderInfo[currentlyOnAuction].bidderAddress==address(0))
        {
            nftItems[currentlyOnAuction].isOnAuction = false;
            nftItems[currentlyOnAuction].bidEndTime = 0;
        }
    
        isCurrentlyOnAuction = false;
        currentlyOnAuction = 0;
    }

    function withdraw()
        public
        onlyOwner
    {
        require(address(this).balance.sub(totalAmountDue)>0,"Cannot withdraw at this time");
        payable(msg.sender).transfer(address(this).balance.sub(totalAmountDue));
    }

    function getOwnerBalance()
        public
        view
        returns(uint256)
    {

        return address(this).balance.sub(totalAmountDue);
    }

    function getBalance()
        public
        view
        returns(uint256)
    {
        return address(this).balance;
    }
  
    function fetchMarketItems()
        public
        view
        returns (MarketItem[] memory)
    {
        uint itemCount = _itemIds.current();
        uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
    
        for (uint i = 0; i < _itemIds.current(); i++)
        {
            if (nftItems[i + 1].owner == address(0))
            {
                uint currentId = i + 1;
                MarketItem storage currentItem = nftItems[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
  
    function fetchMyNFTs(
        address userAddress)
        public
        view
        returns (MarketItem[] memory)
    {
        uint itemCount = 0;
        uint currentIndex = 0;

        for (uint i = 0; i < _itemIds.current(); i++)
        {
            if (nftItems[i + 1].owner == userAddress)
            {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint i = 0; i < _itemIds.current(); i++)
        {
            if (nftItems[i + 1].owner == userAddress)
            {
                uint currentId = i + 1;
                MarketItem storage currentItem = nftItems[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function drawForWinner(
        uint256 _campaignId)
        public
        onlyOwner
    {
        require(campaigns[_campaignId].creatorAddress!=address(0),"Invalid campaign id");
        require(!campaigns[_campaignId].isEnded,"Campaign already ended");
        require(campaigns[_campaignId].drawTime<block.timestamp 
        || campaigns[_campaignId].currentNoOfParticipants==campaigns[_campaignId].maxNoOfParticipants
        ,"Cannot draw at the moment");

        uint256 winnerIndex = RandomContract(randomContract).random() % campaigns[_campaignId].currentNoOfParticipants;

        address winnerAddress = campaigns[_campaignId].participants[winnerIndex];

        campaigns[_campaignId].winnerAddress = winnerAddress;
        campaigns[_campaignId].isEnded = true;
    }

    function getCampaignData(
        uint256 _id)
        public
        view
        returns(
        uint8[] memory nfts,
        string[] memory winnerPrizeImages,
        address[] memory participants
        )
    {
        nfts = campaigns[_id].tokenIDs;
        winnerPrizeImages = campaigns[_id].winnerPrizeImages;
        participants = campaigns[_id].participants;
        return (nfts, winnerPrizeImages, participants);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

}
