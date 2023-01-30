// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Random.sol";

interface ILooxooryNft{
    function mint(address receiver,uint256 amount,string memory _metadataURI) external;
    function getCurrentTokenId() external view returns(uint256);
}

contract LooxooryNFTMarketplace is ReentrancyGuard,Ownable
{
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    Counters.Counter public _itemIds;
    Counters.Counter public _itemsSold;
    Counters.Counter public _campaignIds;

    address public randomContract;
    address public nftContract;
    address public nftHolder;
    
    uint256 public totalSale;

    bool public isCurrentlyOnAuction;
    uint256 public currentlyOnAuction;
    uint256 public TOTAL_PERCENTAGE = 100;

    struct Bidder{
        address bidderAddress;
        uint256 bidderAmount;
    }

    struct MarketItem {
        uint256 itemId;
        uint256 tokenId;
        uint256 price;
        bool sold;
        bool isOnAuction;
        uint256 bidEndTime;
        // string metadataUrl;
        address artistAddress;
        uint256 fractionAmount;
        uint256 remainingAmount;
        uint256 platformFee;
        uint256 itemsSold;
        address owner;
        uint256 campaignID;
    }

    struct CreateMarketItemStruct {
        uint256 price;
        string metadataUrl;
        address artistAddress;
        uint256 fractionAmount;
        uint256 platformFee;
    }

    struct CreateCampaignStruct{
      uint8[] nfts;
      string winnerPrize;
      string[] winnerPrizeImages;
      string campaignDescription;
      uint256 maxNoOfParticipants;
      uint256 drawTime;
      string ngoName;
      string ngoImage;
    }

    struct Campaign {
        uint256 campaignID;
        address creatorAddress;
        uint8[] nfts;
        uint256 totalNfts;
        address winnerAddress;
        string winnerPrize;
        string[] winnerPrizeImages;
        string campaignDescription;
        uint256 maxNoOfParticipants;
        uint256 currentNoOfParticipants;
        uint256 drawTime;
        string ngoName;
        string ngoImage;
        bool isEnded;
        address[] participants;
        uint256 soldNfts;
    }

    mapping(uint256=>MarketItem) public nftItems;
    mapping(uint256=>Campaign) public campaigns;
    mapping(uint256=>Bidder) public bidderInfo;
    uint256 public totalAmountDue;
    uint8[] private filteredNfts;

    event ItemCreated(
        uint256 tokenId,
        uint256 price,
        bool sold,
        bool isOnAuction,
        uint256 bidEndTime,
        address artistAddress,
        uint256 fractionAmount,
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
        string ngoImage
    );

    event ItemSold(
      uint256 itemId,
      uint256 tokenId,
      address seller,
      address buyer,
      uint256 price
    );

    event BidAdded(
      uint256 itemId,
      uint256 tokenId,
      address bidder,
      uint256 amount
    );

    event BidReturned(
      uint256 itemId,
      uint256 tokenId,
      address bidder,
      uint256 amount
    );

    constructor(address _nftContract,address _randomContract,address _nftHolder){
        require(_nftContract!=address(0),"Invalid NFT Contract address");
        require(_randomContract!=address(0),"Invalid NFT Contract address");
        require(_nftHolder!=address(0),"Invalid NFT Contract address");
        nftContract = _nftContract;
        randomContract = _randomContract;
        nftHolder = _nftHolder;
    }

    function setNftContract(address _nftContract) external onlyOwner{
        require(_nftContract!=address(0),"Invalid NFT Contract address");
        nftContract = _nftContract;
    }

    function setRandomContract(address _randomContract) external onlyOwner{
        require(_randomContract!=address(0),"Invalid Random Contract address");
        randomContract = _randomContract;
    }

    function setNFTHolder(address _nftHolder) external onlyOwner{
        require(_nftHolder!=address(0),"Invalid NFT Holder address");
        nftHolder = _nftHolder;
    }

    function createCampaign(
        CreateCampaignStruct memory _campaignDTO
        )
        external onlyOwner
    {

        require(_campaignDTO.drawTime>block.timestamp,"Invalid Draw time");
        _campaignIds.increment();
        uint256 currentCampaignId = _campaignIds.current();
        uint8[] memory emptyArr = new uint8[](0);
        filteredNfts = emptyArr;

        for(uint256 i=0;i<_campaignDTO.nfts.length;i++)
        {
          if(nftItems[_campaignDTO.nfts[i]].owner==nftHolder
           && nftItems[_campaignDTO.nfts[i]].campaignID==0
           && !nftItems[_campaignDTO.nfts[i]].isOnAuction )
          {
            nftItems[_campaignDTO.nfts[i]].campaignID = currentCampaignId;
            filteredNfts.push(_campaignDTO.nfts[i]);
          }
        }

        address[] memory participants;

        campaigns[currentCampaignId] = Campaign
        (
            {
                campaignID:currentCampaignId,
                creatorAddress:msg.sender,
                winnerAddress:address(0),
                nfts:filteredNfts,
                totalNfts:filteredNfts.length,
                winnerPrize:_campaignDTO.winnerPrize,
                winnerPrizeImages:_campaignDTO.winnerPrizeImages,
                campaignDescription:_campaignDTO.campaignDescription,
                maxNoOfParticipants:_campaignDTO.maxNoOfParticipants,
                currentNoOfParticipants:0,
                drawTime:_campaignDTO.drawTime,
                ngoName:_campaignDTO.ngoName,
                ngoImage:_campaignDTO.ngoImage,
                isEnded:false,
                participants:participants,
                soldNfts:0
            }
        );

        emit CampaignCreated
        (
            currentCampaignId,
            msg.sender, 
            _campaignDTO.nfts,
            address(0), 
            _campaignDTO.winnerPrize, 
            _campaignDTO.winnerPrizeImages, 
            _campaignDTO.campaignDescription, 
            _campaignDTO.maxNoOfParticipants, 
            0, 
            _campaignDTO.drawTime, 
            _campaignDTO.ngoName, 
            _campaignDTO.ngoImage 
        );
    }

    function createMarketItem(
        CreateMarketItemStruct memory marketItem
        )
        external
        onlyOwner
    {
        require(marketItem.fractionAmount<=10000,"Amount cannot be greator than 10,000");
        require(marketItem.platformFee>=5 && marketItem.platformFee<=50,"Invalid platform fee");
        _itemIds.increment();
        uint256 itemId = _itemIds.current();
        
        ILooxooryNft(nftContract).mint(nftHolder,marketItem.fractionAmount,marketItem.metadataUrl);
        
        uint256 tokenId = ILooxooryNft(nftContract).getCurrentTokenId();
        
        uint256 priceForEach = marketItem.price;
        
        if(marketItem.fractionAmount>1){
            priceForEach = marketItem.price / marketItem.fractionAmount;
        }

        nftItems[itemId] = MarketItem ({
            itemId:itemId,
            tokenId:tokenId,
            price:priceForEach,
            sold:false,
            isOnAuction:false,
            bidEndTime:0,
            // metadataUrl:marketItem.metadataUrl,
            artistAddress:marketItem.artistAddress,
            fractionAmount:marketItem.fractionAmount,
            remainingAmount:marketItem.fractionAmount,
            platformFee:marketItem.platformFee,
            itemsSold:0,
            owner:nftHolder,
            campaignID:0
        });

        emit ItemCreated
        (
            tokenId, 
            priceForEach, 
            false, 
            false, 
            0, 
            marketItem.artistAddress, 
            marketItem.fractionAmount, 
            marketItem.platformFee, 
            nftHolder
        );
    }

    function createMarketSale(
        uint256 itemId,
        uint256 amount
        )
        external
        payable
        nonReentrant
    {
        require(nftItems[itemId].campaignID!=0,"NFT is not in any campaign");
        require(amount>=1,"Invalid amount");
        require(amount<=nftItems[itemId].remainingAmount,"Invalid amount");

        uint256 campaignID = nftItems[itemId].campaignID;
        uint256 price = nftItems[itemId].price.mul(amount);
        uint256 tokenId = nftItems[itemId].tokenId;
        require(campaigns[campaignID].drawTime>=block.timestamp,"Draw time already completed");
        require(campaigns[campaignID].currentNoOfParticipants<campaigns[campaignID].maxNoOfParticipants,"Campaign already completed");

        require(!nftItems[itemId].isOnAuction,"Cannot buy directly");
        require(!nftItems[itemId].sold,"Already sold");
        require(msg.value == price, "Please submit the asking price in order to complete the purchase");
        require(msg.sender!=nftItems[itemId].owner,"Already owned");
      
        campaigns[campaignID].currentNoOfParticipants = campaigns[campaignID].currentNoOfParticipants.add(1);
        campaigns[campaignID].soldNfts = campaigns[campaignID].soldNfts.add(1);
        campaigns[campaignID].participants.push(msg.sender);
        _itemsSold.increment();
        totalSale = totalSale.add(price);
        nftItems[itemId].remainingAmount = nftItems[itemId].remainingAmount.sub(amount);
    
        emit ItemSold(itemId, tokenId, nftItems[itemId].owner , msg.sender, amount);

        IERC1155(nftContract).safeTransferFrom(nftItems[itemId].owner, msg.sender, tokenId,amount,"");
        uint256 platformFee = price.mul(nftItems[itemId].platformFee).div(TOTAL_PERCENTAGE);
        uint256 artistShare = price.sub(platformFee);
      
        payable(nftItems[itemId].artistAddress).transfer(artistShare);

        if(nftItems[itemId].remainingAmount==0){
            nftItems[itemId].sold = true;
        }
    }

    function listNftForAuction(
        uint256 nftID,
        uint256 bidEndTime)
        external
        onlyOwner
    {
        require(nftItems[nftID].tokenId!=0,"Invalid nft ID to auction");
        require(nftItems[nftID].campaignID==0,"nft already listed on a campaign");
        require(nftItems[nftID].fractionAmount==1,"NFT Amount must not be in fraction");
        require(!nftItems[nftID].sold,"NFT is already sold");
        require(nftItems[nftID].owner==nftHolder,"Cannot list this nft");
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
        external
        payable
        nonReentrant
    {
        uint price = nftItems[itemId].price;
  
        require(nftItems[itemId].isOnAuction,"Item is not on auction");
        require(nftItems[itemId].bidEndTime>block.timestamp,"Auction time ended");
        require(!nftItems[itemId].sold,"Already sold");
        require(msg.sender!=nftItems[itemId].owner,"Already owned");
        require(msg.value >= price && msg.value > bidderInfo[itemId].bidderAmount, "Bid price must be greater than base price and highest bid");

        if(bidderInfo[itemId].bidderAddress!=address(0))
        {
            payable(bidderInfo[itemId].bidderAddress).transfer(bidderInfo[itemId].bidderAmount);
            totalAmountDue = totalAmountDue.sub(bidderInfo[itemId].bidderAmount);
            emit BidReturned(itemId, nftItems[itemId].tokenId, bidderInfo[itemId].bidderAddress, bidderInfo[itemId].bidderAmount);(itemId, nftItems[itemId].tokenId, msg.sender, msg.value);
        }
        totalAmountDue = totalAmountDue.add(msg.value);
        bidderInfo[itemId].bidderAddress = msg.sender;
        bidderInfo[itemId].bidderAmount = msg.value;

        emit BidAdded(itemId, nftItems[itemId].tokenId, msg.sender, msg.value);
    }

    function claimBidItem(
        uint256 itemId)
        external
        nonReentrant
    {
        require(nftItems[itemId].isOnAuction,"Item is not on auction");
        require(nftItems[itemId].bidEndTime<=block.timestamp,"Bidding is still in progress");
        uint tokenId = nftItems[itemId].tokenId;

        require(msg.sender!=nftItems[itemId].owner,"Already owned");
        require(bidderInfo[itemId].bidderAddress==msg.sender,"Only highest bidder can claim the NFT");
    
        uint256 price = bidderInfo[itemId].bidderAmount;
    
        _itemsSold.increment();
        totalSale = totalSale.add(price);

        totalAmountDue = totalAmountDue.sub(price);
        IERC1155(nftContract).safeTransferFrom(nftHolder, msg.sender, tokenId,nftItems[itemId].fractionAmount,"");

        uint256 platformFee = price.mul(nftItems[itemId].platformFee).div(TOTAL_PERCENTAGE);
        uint256 artistShare = price.sub(platformFee);
    
        payable(nftItems[itemId].artistAddress).transfer(artistShare);

        nftItems[itemId].sold = true;
        nftItems[itemId].remainingAmount = nftItems[itemId].remainingAmount.sub(1);

        if(currentlyOnAuction == itemId)
        {
            isCurrentlyOnAuction = false;
            currentlyOnAuction = 0;
        }
    }

    function resetAuction()
        external
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
        external
        onlyOwner
    {
        uint256 amount = address(this).balance.sub(totalAmountDue);
        require(amount>0,"Cannot withdraw at this time");
        payable(msg.sender).transfer(amount);
    }

    function getOwnerBalance()
        public
        view
        returns(uint256)
    {
        uint256 amount = address(this).balance.sub(totalAmountDue);
        return amount;
    }

    function getBalance()
        public
        view
        returns(uint256)
    {
        return address(this).balance;
    }
  
    function fetchMarketItems()
        external
        view
        returns (MarketItem[] memory)
    {
        uint itemCount = _itemIds.current();
        uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
    
        for (uint i = 0; i < itemCount; i++)
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
        external
        view
        returns (MarketItem[] memory)
    {
        uint totalItemCount = _itemIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        for (uint i = 0; i < totalItemCount; i++)
        {
            if (nftItems[i + 1].owner == userAddress)
            {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint i = 0; i < totalItemCount; i++)
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
        external
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
        external
        view
        returns(
        uint8[] memory nfts,
        string[] memory winnerPrizeImages,
        address[] memory participants
        )
    {
        nfts = campaigns[_id].nfts;
        winnerPrizeImages = campaigns[_id].winnerPrizeImages;
        participants = campaigns[_id].participants;
    }
}
