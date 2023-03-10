// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
pragma abicoder v2; // required to accept structs as function parameters

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";


contract lazyMinting is
    ERC721URIStorage,
    EIP712,
    AccessControl
{
    string private constant SIGNING_DOMAIN = "LazyNFT-Voucher";
    string private constant SIGNATURE_VERSION = "1";

  constructor()
    ERC721("LazyNFT", "LAZ") 
    EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
    }

    struct NFTVoucher
    {
    /// @notice The id of the token to be redeemed. Must be unique - if another token with this ID already exists, the redeem function will revert.
      uint256 voucherId;
      address ownerAddrress;
    /// @notice The minimum price (in wei) that the NFT creator is willing to accept for the initial sale of this NFT.
      uint256 minPrice;
    /// @notice The metadata URI to associate with this token.
      string uri;
    /// @notice the EIP-712 signature of all other fields in the NFTVoucher struct. For a voucher to be valid, it must be signed by an account with the MINTER_ROLE.
      bytes signature;
    }

    mapping(address => NFTVoucher) private ownedNFTs;

  /// @notice Redeems an NFTVoucher for an actual NFT, creating it in the process.
  /// @param voucher A signed NFTVoucher that describes the NFT to be redeemed.
  function lazyMint(
    NFTVoucher calldata voucher)
    public
    payable
    returns(uint256)
  {
    // make sure signature is valid and get the address of the signer
    address signer = _verify(voucher);
    // make sure that the signer is authorized to mint NFTs
    // make sure that the redeemer is paying enough to cover the buyer's cost
    require(msg.value == voucher.minPrice, "Insufficient funds to redeem");

    // first assign the token to the signer, to establish provenance on-chain
    _mint(signer, voucher.voucherId);
    _setTokenURI(voucher.voucherId, voucher.uri);
    
    // transfer the token to the redeemer
    safeTransferFrom(signer, msg.sender, voucher.voucherId);

    payable (signer).transfer(voucher.minPrice);

    return voucher.voucherId;
  }

  
  /// @notice Returns a hash of the given NFTVoucher, prepared using EIP712 typed data hashing rules.
  /// @param voucher An NFTVoucher to hash.
  function _hash(
    NFTVoucher calldata voucher)
    internal
    view
    returns(bytes32)
  {
    return 
    _hashTypedDataV4(
      keccak256(abi.encode(
      keccak256("NFTVoucher(uint256 tokenId,uint256 minPrice,string uri)"),
      voucher.voucherId,
      voucher.minPrice,
      voucher.ownerAddrress,
      keccak256(bytes(voucher.uri))
    )));
  }

  /// @notice Verifies the signature for a given NFTVoucher, returning the address of the signer.
  /// @dev Will revert if the signature is invalid. Does not verify that the signer is authorized to mint NFTs.
  /// @param voucher An NFTVoucher describing an unminted NFT.
  function _verify(
    NFTVoucher calldata voucher)
    internal
    view
    returns(address)
  {
    bytes32 digest = _hash(voucher);
    return ECDSA.recover(digest, voucher.signature);
  }

  function supportsInterface(
    bytes4 interfaceId)
    public
    view
    virtual
    override(AccessControl,
    ERC721)
    returns(bool)
  {
    return ERC721.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
  }
}
