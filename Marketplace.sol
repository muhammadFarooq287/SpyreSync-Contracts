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
        uint256 _minPrice, 
        string memory  _uri,
        address _artistAddress,
        bytes memory _signature
        )
        external;

    function getCurrenttokenID()
        external
        view
        returns(uint256);
}

contract Marketplace is
    ReentrancyGuard,
    Ownable,
    ERC721,
    ERC721URIStorage,
    EIP712 
{
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    uint IDNft=0;

    
    string private constant SIGNING_DOMAIN = "LazyNFT-Voucher";
    string private constant SIGNATURE_VERSION = "1";

    address public randomContract;
    address public nftContract;
    address public voucherHolder;

    struct NFTVoucher {
        uint256 tokenId;
        uint256 price;
        string uri;
        address artist;
        bytes signature;
    }

    mapping(uint256=>NFTVoucher) public nftItems;

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

     function redeemVoucher(
        NFTVoucher calldata voucher)
        public
        nonReentrant
    {
        ILooxooryNft(nftContract).lazyMint(
            voucher.tokenId,
            voucher.price,
            voucher.uri,
            voucher.artist,
            voucher.signature);
        IERC721(nftContract).transferFrom(voucherHolder, msg.sender,voucher.tokenId);
        IDNft+=1;
        nftItems[IDNft].tokenId = voucher.tokenId;
        nftItems[IDNft].price = voucher.price;
        nftItems[IDNft].uri = voucher.uri;
        nftItems[IDNft].artist= voucher.artist;
        nftItems[IDNft].signature = voucher.signature;

        payable(nftItems[IDNft].artist).transfer(nftItems[IDNft].price);

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
