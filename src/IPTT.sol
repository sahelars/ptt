// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

/// @title Physically Transferrable Tokens (PTT)
interface IPTT {
    /// @notice Emits when receiving address sends payment for offer
    /// @dev MUST emit in initializeOffer
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

    /// @notice Emits when receiving address reverts offer
    /// @dev MUST emit in revertOffer
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
    /// @dev MUST emit in acceptOffer
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

    /// @notice Emits when receiving address refunds offer
    /// @dev MUST emit in refundOffer
    /// @param _from The address who owns the _tokenId
    /// @param _to The initializer address
    /// @param _tokenId The token ID for the offer
    /// @param _offer The offer amount for the token ID
    event RefundOffer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId,
        uint256 _offer
    );

    /// @notice Emits when initializer confirms their transfer
    /// @dev Compatible with ERC-721 and MUST emit with transfer
    /// @param _from The address who owns the _tokenId
    /// @param _to The initializer address
    /// @param _tokenId The token ID for the offer
    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );

    /// @notice Initialize a token offer to transfer to the sender
    /// @dev MUST emit InitializeOffer event
    /// @param _initializer The potential transferee of the offer
    /// @param _tokenId The token ID to offer ETH for
    function initializeOffer(address _initializer, uint256 _tokenId)
        external
        payable;

    /// @notice Revert a token offer
    /// @dev MUST emit RevertOffer event
    /// @param _tokenId The token ID to revert offer for
    function revertOffer(uint256 _tokenId) external;

    /// @notice Accept a token offer but does not send payment
    /// @dev MUST emit AcceptOffer event and prevent revertOffer
    /// @param _from The address that owners the token
    /// @param _to The address who will receive the token
    /// @param _tokenId The token ID to accept offer for
    function acceptOffer(
        address _from,
        address _to,
        uint256 _tokenId
    ) external;

    /// @notice Refund a token offer
    /// @dev MUST emit RefundOffer event
    /// @param _initializer The initializer to receive refund
    /// @param _tokenId The token ID to refund offer for
    function refundOffer(address _initializer, uint256 _tokenId) external;

    /// @notice Transfers the sends ETH to the _from address
    /// @dev Compatible with ERC-721 and MUST emit Transfer event
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
    /// @dev Compatible with ERC-721 and should be set after transfer
    /// @param _tokenId The owner token ID
    function ownerOf(uint256 _tokenId) external view returns (address);

    /// @notice Initalized receiver for after Accept is emitted
    /// @dev The transferee is initializer after offer is accepted
    /// @param _tokenId The token ID for the initializer
    function transferee(uint256 _tokenId) external view returns (address);

    /// @notice The offer amount for a token ID from an initializer
    /// @param _initializer The initializer of the offer
    /// @param _tokenId The token ID for the initializer
    function initializerTokenOffer(address _initializer, uint256 _tokenId)
        external
        view
        returns (uint256);
}
