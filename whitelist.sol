// SPDX-License-Identifier: MIT
// eyJuYW1lIjoiME4xIC0gTWV0YWRhdGEiLCJkZXNjcmlwdGlvbiI6IlRoaXMgc2hvdWxkIE5PVCBiZSByZXZlYWxlZCBiZWZvcmUgYWxsIGFyZSBzb2xkLiBJbWFnZXMgY29udGFpbmVkIGJlbG93IiwiaW1hZ2VzIjoiMHg1MTZENTU0ODYxMzQ0QTc3NEI1MDY3NjY0ODcxNDM1ODMxNTQ3ODMyNTc2OTRBNTg2NDYzNEM2MzY1NTM3NDZGNTEzNjY1Nzg1NTU4Mzg1NDRBNkE0NjYxNjE1MSJ9
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

contract MerkleProof {
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf,
        uint index
    ) public pure returns (bool) {
        bytes32 hash = leaf;

        for (uint i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (index % 2 == 0) {
                hash = keccak256(abi.encodePacked(hash, proofElement));
            } else {
                hash = keccak256(abi.encodePacked(proofElement, hash));
            }

            index = index / 2;
        }

        return hash == root;
    }
}


contract TemptusUTS is ERC721Enumerable, Ownable, MerkleProof {
  using Strings for uint256;

  uint256 public constant UTS_GIFT = 0;
  uint256 public constant UTS_PUBLIC = 7_750;
  uint256 public constant UTS_MAX = UTS_GIFT + UTS_PUBLIC;
  uint256 public PURCHASE_LIMIT = 70;
  uint256 public constant PRICE = 0.0775 ether;

  bool public isActive = false;
  bool public isAllowListActive = false;
  string public proof;

  uint256 public constant allowListMaxMint = 1000;
  uint256 public constant allowListMaxMintPerTx = 20;
  /// @dev We will use these to be able to calculate remaining correctly.
  uint256 public totalGiftSupply;
  uint256 public totalPublicSupply;
  bytes32 public _merkleRoot;
  mapping(address => uint256) private _allowListClaimed;

  string private _contractURI = '';
  string private _tokenBaseURI = '';
  string private _tokenRevealedBaseURI = '';
  address public _paymentSplitter;
  uint256 public startingIndex = 0;

  constructor(string memory name, string memory symbol, address paymentSplitter) ERC721(name, symbol) {
      _paymentSplitter = paymentSplitter;
  }
  
  function setWhitelistMerkleRoot(bytes32 a) external onlyOwner {
    _merkleRoot = a;
  }
  
  function setPurchaseLimit(uint a) external onlyOwner {
    PURCHASE_LIMIT = a;
  }

  function onAllowList(string memory _who, bytes32[] calldata _proof, uint index) public view returns (bool) {
    return verify(_proof, _merkleRoot, keccak256(abi.encodePacked(_who)), index);
  }
  
  function addressToString(address _addr) public pure returns(string memory) {
    bytes32 value = bytes32(uint256(uint160(_addr)));
    bytes memory alphabet = "0123456789abcdef";

    bytes memory str = new bytes(51);
    str[0] = "0";
    str[1] = "x";
    for (uint i = 0; i < 20; i++) {
        str[2+i*2] = alphabet[uint(uint8(value[i + 12] >> 4))];
        str[3+i*2] = alphabet[uint(uint8(value[i + 12] & 0x0f))];
    }
    return string(str);
  }


  /**
  * @dev We want to be able to distinguish tokens bought during isAllowListActive
  * and tokens bought outside of isAllowListActive
  */
  function allowListClaimedBy(address owner) external view  returns (uint256){
    require(owner != address(0), 'Zero address not on Allow List');

    return _allowListClaimed[owner];
  }

  function purchase(uint256 numberOfTokens) external  payable {
    require(isActive, 'Contract is not active');
    require(!isAllowListActive, 'Only allowing from Allow List');
    require(totalSupply() < UTS_MAX, 'All tokens have been minted');
    require(numberOfTokens <= PURCHASE_LIMIT, 'Would exceed PURCHASE_LIMIT');
    /**
    * @dev The last person to purchase might pay too much.
    * This way however they can't get sniped.
    * If this happens, we'll refund the Eth for the unavailable tokens.
    */
    require(totalPublicSupply < UTS_PUBLIC, 'Purchase would exceed UTS_PUBLIC');
    require(PRICE * numberOfTokens <= msg.value, 'ETH amount is not sufficient');

    for (uint256 i = 0; i < numberOfTokens; i++) {
      /**
      * @dev Since they can get here while exceeding the UTS_MAX,
      * we have to make sure to not mint any additional tokens.
      */
      if (totalPublicSupply < UTS_PUBLIC) {
        /**
        * @dev Public token numbering starts after UTS_GIFT.
        * And we don't want our tokens to start at 0 but at 1.
        */
        uint256 tokenId = UTS_GIFT + totalPublicSupply + 1;

        totalPublicSupply += 1;
        _safeMint(msg.sender, tokenId);
      }
    }
  }

  function purchaseAllowList(uint256 numberOfTokens, bytes32[] calldata _proof, uint index) external  payable {
    require(isActive, 'Contract is not active');
    require(isAllowListActive, 'Allow List is not active');
    require(onAllowList(addressToString(msg.sender), _proof, index), 'You are not on the Allow List');
    require(totalSupply() < UTS_MAX, 'All tokens have been minted');
    require(numberOfTokens <= allowListMaxMintPerTx, 'Cannot purchase this many tokens');
    require(totalPublicSupply + numberOfTokens <= allowListMaxMint, 'Purchase would exceed allowListMaxMint');
    // require(_allowListClaimed[msg.sender] + numberOfTokens <= allowListMaxMint, 'Purchase exceeds max allowed');
    require(PRICE * numberOfTokens <= msg.value, 'ETH amount is not sufficient');

    for (uint256 i = 0; i < numberOfTokens; i++) {
      /**
      * @dev Public token numbering starts after UTS_GIFT.
      * We don't want our tokens to start at 0 but at 1.
      */
      uint256 tokenId = UTS_GIFT + totalPublicSupply + 1;

      totalPublicSupply += 1;
      _allowListClaimed[msg.sender] += 1;
      _safeMint(msg.sender, tokenId);
    }
  }

  function gift(address[] calldata to) external  onlyOwner {
    require(totalSupply() < UTS_MAX, 'All tokens have been minted');
    require(totalGiftSupply + to.length <= UTS_GIFT, 'Not enough tokens left to gift');

    for(uint256 i = 0; i < to.length; i++) {
      /// @dev We don't want our tokens to start at 0 but at 1.
      uint256 tokenId = totalGiftSupply + 1;

      totalGiftSupply += 1;
      _safeMint(to[i], tokenId);
    }
  }

  function setIsActive(bool _isActive) external  onlyOwner {
    isActive = _isActive;
  }

  function setIsAllowListActive(bool _isAllowListActive) external  onlyOwner {
    isAllowListActive = _isAllowListActive;
  }

//   function setAllowListMaxMint(uint256 maxMint) external  onlyOwner {
//     allowListMaxMint = maxMint;
//   }

  function setProof(string calldata proofString) external  onlyOwner {
    proof = proofString;
  }

  function withdraw() external  onlyOwner {
    uint256 balance = address(this).balance;

    payable(_paymentSplitter).transfer(balance);
  }

  function setContractURI(string calldata URI) external  onlyOwner {
    _contractURI = URI;
  }

  function setBaseURI(string calldata URI) external  onlyOwner {
    _tokenBaseURI = URI;
  }

  function setRevealedBaseURI(string calldata revealedBaseURI) external  onlyOwner {
    _tokenRevealedBaseURI = revealedBaseURI;
  }

  function contractURI() public view  returns (string memory) {
    return _contractURI;
  }

  function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
    require(_exists(tokenId), 'Token does not exist');

    /// @dev Convert string to bytes so we can check if it's empty or not.
    string memory revealedBaseURI = _tokenRevealedBaseURI;
    return bytes(revealedBaseURI).length > 0 ?
      string(abi.encodePacked(revealedBaseURI, tokenId.toString())) :
      _tokenBaseURI;
  }
}