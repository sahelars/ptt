// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

/// @title Physically Transferrable Tokens (PTT)
interface IPTT {
    /// @notice Emits when receiving address sends payment for transaction
    /// @param _from The address who owns the _tokenId
    /// @param _to The initializer address
    /// @param _tokenId The token ID for the offer
    /// @param _offer The offer amount for the token ID
    event Initialize(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId,
        uint256 _offer
    );

    /// @notice Emits when receiving address reverts transaction
    /// @param _from The address who owns the _tokenId
    /// @param _to The initializer address
    /// @param _tokenId The token ID for the offer
    /// @param _offer The offer amount for the token ID
    event Revert(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId,
        uint256 _offer
    );

    /// @notice Emits when owner accepts offer and gives initializer PTT
    /// @param _from The address who owns the _tokenId
    /// @param _to The initializer address
    /// @param _tokenId The token ID for the offer
    /// @param _offer The offer amount for the token ID
    event Accept(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId,
        uint256 _offer
    );

    /// @notice Emits when initializer confirms their transfer
    /// @dev Compatible with ERC-721
    /// @param _from The address who owns the _tokenId
    /// @param _to The initializer address
    /// @param _tokenId The token ID for the offer
    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );

    /// @notice Returns true if the transfer code is valid
    /// @param _tokenId The token ID for the transfer code
    /// @param _code The code used to transfer the token
    /// @param _proof The merkle proof for the code
    function isApprovedForTransfer(
        uint256 _tokenId,
        string memory _code,
        bytes32[] calldata _proof
    ) external view returns (bool);

    /// @notice The balance of a token owner
    /// @dev Compatible with ERC-721
    /// @param _owner The owner address of the token
    function balanceOf(address _owner) external view returns (uint256);

    /// @notice The owner of a token
    /// @dev Compatible with ERC-721
    /// @param _tokenId The owner token ID
    function ownerOf(uint256 _tokenId) external view returns (address);

    /// @notice Initalized receiver for after Accept is emitted
    /// @param _tokenId The token ID for the initializer
    function initialized(uint256 _tokenId) external view returns (address);

    /// @notice The offer amount for a token ID from an initializer
    /// @param _tokenId The token ID for the initializer
    /// @param _initializer The initializer of the offer
    function offer(uint256 _tokenId, address _initializer)
        external
        view
        returns (uint256);
}
