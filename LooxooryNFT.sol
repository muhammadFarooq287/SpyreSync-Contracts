// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

contract LazyNFT is ERC721, ERC721URIStorage, Ownable, EIP712 {
    string private constant SIGNING_DOMAIN = "Voucher-Domain";
    string private constant SIGNATURE_VERSION = "1";
    address public minter;

    constructor(address _minter) ERC721("LazyNFT", "LNFT") EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
        minter = _minter;
    }

    struct LazyNFTVoucher {
        uint256 tokenId;
        uint256 price;
        string uri;
        address buyer;
        bytes signature;
    }

    function recover(LazyNFTVoucher calldata voucher) public view returns (address) {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            keccak256("LazyNFTVoucher(uint256 tokenId,uint256 price,string uri,address buyer)"),
            voucher.tokenId,
            voucher.price,
            keccak256(bytes(voucher.uri)),
            voucher.buyer
        )));
        address signer = ECDSA.recover(digest, voucher.signature);
        return signer;
    }

    function safeMint(LazyNFTVoucher calldata voucher)
        public
        payable
    {
        require(minter == recover(voucher), "Wrong signature.");
        require(msg.value >= voucher.price, "Not enough ether sent.");
        _safeMint(voucher.buyer, voucher.tokenId);
        _setTokenURI(voucher.tokenId, voucher.uri);
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


/**import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract LooxooryNFT is ERC1155, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(uint256=>string) public metadataURIs;
    address public minterAddress;
    
    modifier onlyMinter{
        require(msg.sender==minterAddress,"You are not allowed to do this operation");
        _;
    }

    constructor(address _minterAddress) ERC1155("LooxooryNFT") {
        require(_minterAddress!=address(0),"Invalid address for minter role");
        minterAddress = _minterAddress;
    }    
    
    function setMinterAddress(address _minterAddress) external onlyOwner{
        require(_minterAddress!=address(0),"Invalid address for minter role");
        minterAddress = _minterAddress;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function totalSupply() public view returns (uint256) {
        uint256 totalMintedNFTs = _tokenIds.current();
        return totalMintedNFTs;
    }

     function mint(address receiver,uint256 amount,string memory _metadataURI) public onlyMinter {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        metadataURIs[newItemId] = _metadataURI;
        _mint(receiver, newItemId, amount, "");
    }

    function uri(uint256 _id) public view virtual override returns (string memory) {
        return metadataURIs[_id];
    }

    function getCurrentTokenId() public view returns(uint256){
        return _tokenIds.current();
    }
}*/
