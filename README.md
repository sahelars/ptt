---
eip: <to be assigned>
title: Physically Transferrable Token
description: Interface for linking ownership to physical items and escrow for their exchange
author: Sam Larsen
discussions-to: CryptoDevs (Discord)
status: Draft
type: Standards Track
category: ERC
created: 2022-10-20
requires: 165
---

## Abstract

This standard proposes an interface for exchanging physical items for ETH through an escrow blockchain service. The NFTs may only be transferred using a physical device that will generate transfer codes without an internet connection.

## Motivation

This proposal is motivated to add blockchain transparency and utility to physical items and include an escrow service for their exchange. An example of this could be the sale of smart vehicles or smart homes.

## Specification

The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHALL”, “SHALL NOT”, “SHOULD”, “SHOULD NOT”, “RECOMMENDED”, “MAY”, and “OPTIONAL” in this document are to be interpreted as described in RFC 2119.

Each NFT must be operated by a physical chip, preferrably an NFC chip. The physical chip must contain a merkle tree database that must chronologically release codes and the codes must increase in size. The escrow system must ensure old codes cannot be used after the new owner is stored.

**Every ERC-???? compliant contract must implement the `ERC` and `ERC165` interfaces (subject to "caveats" below):**

```solidity
interface ERC {
    /// @notice Emits when receiving address sends payment for transaction
    /// @dev Implemented with initializeOffer
    /// @param _from The address who owns the _tokenId
    /// @param _to The initializer address
    /// @param _tokenId The token ID for the offer
    /// @param _offer The offer amount for the token ID
    event InitializeOffer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId,
        uint256 _offer
    );

    /// @notice Emits when receiving address reverts transaction
    /// @dev Implemented with revertOffer
    /// @param _from The address who owns the _tokenId
    /// @param _to The initializer address
    /// @param _tokenId The token ID for the offer
    /// @param _offer The offer amount for the token ID
    event RevertOffer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId,
        uint256 _offer
    );

    /// @notice Emits when owner accepts offer and gives initializer PTT
    /// @dev Implemented with acceptOffer
    /// @param _from The address who owns the _tokenId
    /// @param _to The initializer address
    /// @param _tokenId The token ID for the offer
    /// @param _offer The offer amount for the token ID
    event AcceptOffer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId,
        uint256 _offer
    );

    /// @notice Emits when initializer confirms their transfer
    /// @dev Compatible with ERC-721 and implemented with transfer
    /// @param _from The address who owns the _tokenId
    /// @param _to The initializer address
    /// @param _tokenId The token ID for the offer
    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );

    /// @notice Initialize a token offer to transfer to the sender
    /// @dev Should emit InitializeOffer event
    /// @param _tokenId The token ID to offer ETH for
    function initializeOffer(uint256 _tokenId) external payable;

    /// @notice Revert a token offer
    /// @dev Should emit RevertOffer event
    /// @param _tokenId The token ID to revert offer for
    function revertOffer(uint256 _tokenId) external;

    /// @notice Accept a token offer but does not send payment
    /// @dev Emit AcceptOffer event and prevent revertOffer
    /// @param _from The address that owners the token
    /// @param _to The address who will receive the token
    /// @param _tokenId The token ID to accept offer for
    /// @param _code An indexed code from the merkle tree database
    /// @param _proof The proof for the code
    function acceptOffer(
        address _from,
        address _to,
        uint256 _tokenId,
        string memory _code,
        bytes32[] calldata _proof
    ) external;

    /// @notice Transfers the sends ETH to the _from address
    /// @dev Compatible with ERC-721 and emit Transfer event
    /// @param _from The address that owners the token
    /// @param _to The address who will receive the token
    /// @param _tokenId The token ID to transfer
    /// @param _code An indexed code from the merkle tree database
    /// @param _proof The proof for the code
    function transfer(
        address _from,
        address _to,
        uint256 _tokenId,
        string memory _code,
        bytes32[] calldata _proof
    ) external;

    /// @notice Returns true if the transfer code is valid
    /// @param _tokenId The token ID for the transfer code
    /// @param _code The code used to transfer the token
    /// @param _proof The merkle proof for the code
    function isValidTransferCode(
        uint256 _tokenId,
        string memory _code,
        bytes32[] calldata _proof
    ) external view returns (bool);

    /// @notice The owner of a token
    /// @dev Compatible with ERC-721
    /// @param _tokenId The owner token ID
    function ownerOf(uint256 _tokenId) external view returns (address);

    /// @notice Initalized receiver for after Accept is emitted
    /// @param _tokenId The token ID for the initializer
    function initializer(uint256 _tokenId) external view returns (address);

    /// @notice The offer amount for a token ID from an initializer
    /// @param _tokenId The token ID for the initializer
    /// @param _initializer The initializer of the offer
    function initializerTokenOffer(address _initializer, uint256 _tokenId)
        external
        view
        returns (uint256);
}
```

## Rationale

The interface includes an escrow system to ensure a smooth physical transfer process between the old owner and new owner and a set of events that are unique to the physical trade off of items.

## Backwards Compatibility

This proposal is backwards compatible with the Transfer event and ownerOf specs from [ERC-721](./eip-721.md).

## Reference Implementation

The following is a basic non-optimized implementation of the ERC-????:

```solidity
import "./IERC.sol";
import "@0xver/solver/library/Merkle.sol";
import "@0xver/solver/interface/IERC165.sol";

contract ERC is IERC, IERC165 {
    mapping(uint256 => address) public override(IPTT) ownerOf;
    mapping(uint256 => address) public override(IPTT) initializer;
    mapping(address => mapping(uint256 => uint256))
        public
        override(IPTT) initializerTokenOffer;
    mapping(uint256 => mapping(bytes32 => uint256)) private _processedMap;
    mapping(uint256 => uint256) private _lastProcessed;
    mapping(uint256 => bytes32) private _tokenRootMap;
    uint256 private _currentTokenId;

    function mint(bytes32 _root) public {
        _currentTokenId += 1;
        ownerOf[_currentTokenId] = msg.sender;
        _setTokenRoot(_currentTokenId, _root);
        emit Transfer(address(0), msg.sender, _currentTokenId);
    }

    function isValidTransferCode(
        uint256 _tokenId,
        string memory _code,
        bytes32[] calldata _proof
    ) public view override(IPTT) returns (bool) {
        if (Strings.numbify(_code) <= _lastProcessed[_tokenId]) {
            return false;
        }
        bytes32 leaf = keccak256(abi.encodePacked(_code));
        return Merkle.verify(_proof, _tokenRoot(_tokenId), leaf);
    }

    function initializeOffer(uint256 _tokenId) public payable override(IPTT) {
        require(initializer[_tokenId] == address(0));
        initializerTokenOffer[msg.sender][_tokenId] = msg.value;
        emit InitializeOffer(
            ownerOf[_tokenId],
            msg.sender,
            _tokenId,
            msg.value
        );
    }

    function revertOffer(uint256 _tokenId) public override(IPTT) {
        require(initializer[_tokenId] == address(0));
        uint256 amount = initializerTokenOffer[msg.sender][_tokenId];
        delete initializerTokenOffer[msg.sender][_tokenId];
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETHER_TRANSFER_FAILED");
        emit RevertOffer(ownerOf[_tokenId], msg.sender, _tokenId, amount);
    }

    function acceptOffer(
        address _from,
        address _to,
        uint256 _tokenId,
        string memory _code,
        bytes32[] calldata _proof
    ) public override(IPTT) {
        require(
            initializer[_tokenId] == address(0) &&
                _from == ownerOf[_tokenId] &&
                isValidTransferCode(_tokenId, _code, _proof)
        );
        _processLeaf(_tokenId, _code, _proof);
        initializer[_tokenId] = _to;
        emit AcceptOffer(
            ownerOf[_tokenId],
            _to,
            _tokenId,
            initializerTokenOffer[_to][_tokenId]
        );
    }

    function transfer(
        address _from,
        address _to,
        uint256 _tokenId,
        string memory _code,
        bytes32[] calldata _proof
    ) public override(IPTT) {
        require(
            _from == ownerOf[_tokenId] &&
                _to == initializer[_tokenId] &&
                isValidTransferCode(_tokenId, _code, _proof)
        );
        _processLeaf(_tokenId, _code, _proof);
        ownerOf[_tokenId] = _to;
        delete initializer[_tokenId];
        uint256 amount = initializerTokenOffer[_to][_tokenId];
        (bool success, ) = payable(_from).call{value: amount}("");
        require(success, "ETHER_TRANSFER_FAILED");
        emit Transfer(_from, _to, _tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        pure
        virtual
        override(IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IPTT).interfaceId;
    }

    function _setTokenRoot(uint256 _tokenId, bytes32 _root) internal {
        _tokenRootMap[_tokenId] = _root;
    }

    function _tokenRoot(uint256 _tokenId) internal view returns (bytes32) {
        return _tokenRootMap[_tokenId];
    }

    function _processLeaf(
        uint256 _tokenId,
        string memory _code,
        bytes32[] calldata _proof
    ) internal {
        bytes32 leaf = keccak256(abi.encodePacked(_code));
        require(
            Merkle.verify(_proof, _tokenRoot(_tokenId), leaf),
            "INVALID_PROOF"
        );
        uint128 num = uint128(Strings.numbify(_code));
        _processedMap[_tokenId][leaf] = num;
        _lastProcessed[_tokenId] = num;
    }
}

library Strings {
    function numbify(string memory _string)
        internal
        pure
        returns (uint256 number)
    {
        for (uint256 i = 0; i < bytes(_string).length; i++) {
            if (
                (uint8(bytes(_string)[i]) - 48) < 0 ||
                (uint8(bytes(_string)[i]) - 48) > 9
            ) {
                return 0;
            }
            number +=
                (uint8(bytes(_string)[i]) - 48) *
                10**(bytes(_string).length - i - 1);
        }

        return number;
    }
}
```

## Security Considerations

The escrow system should ensure old codes can't be used by previous owners. This can be done by increasing the size of the codes and checking that each code is larger than the previous. After an offer is accepted via `acceptOffer` it should be implemented so `revertOffer` cannot occur after that point.

## Copyright

Copyright and related rights waived via [CC0](../LICENSE.md).