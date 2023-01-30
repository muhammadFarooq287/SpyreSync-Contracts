// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts@4.7.3/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/draft-EIP712.sol";

contract LazyNFT is ERC721, ERC721URIStorage, Ownable, EIP712 {
    string private constant SIGNING_DOMAIN = "LazyNFT-Voucher";
    string private constant SIGNATURE_VERSION = "1";
    address public admin;

    constructor(address _admin) ERC721("LazyNFT", "LNFT") EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
        admin = _admin;
    }

    struct LazyNFTVoucher {
        uint256 tokenId;
        uint256 price;
        string uri;
        address artist;
        bytes signature;
    }

    function recover(LazyNFTVoucher calldata voucher) public view returns (address) {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            keccak256("LazyNFTVoucher(uint256 tokenId,uint256 price,string uri,address buyer)"),
            voucher.tokenId,
            voucher.price,
            keccak256(bytes(voucher.uri)),
            voucher.artist
        )));
        address signer = ECDSA.recover(digest, voucher.signature);
        return signer;
    }

    function safeMint(LazyNFTVoucher calldata voucher)
        public
        payable
        returns(bool)
    {
        require(admin == recover(voucher), "Wrong signature.");
        require(msg.value == voucher.price, "Enter exact price in Wei");
        _safeMint(msg.sender, voucher.tokenId);
        _setTokenURI(voucher.tokenId, voucher.uri);
        payable(voucher.artist).transfer(msg.value);
        return true;
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
