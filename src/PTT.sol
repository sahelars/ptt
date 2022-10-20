// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import "./IPTT.sol";
import "@0xver/solver/library/Merkle.sol";

/// @title Physically Transferrable Token (PTT) implementation
/// @dev This is a non-optimized implementation
contract PTT is IPTT {
    mapping(address => uint256) public override(IPTT) balanceOf;
    mapping(uint256 => address) public override(IPTT) ownerOf;
    mapping(uint256 => address) public override(IPTT) initialized;
    mapping(uint256 => mapping(address => uint256)) public override(IPTT) offer;
    mapping(uint256 => mapping(bytes32 => uint256)) private _processedMap;
    mapping(uint256 => uint256) private _lastProcessed;
    mapping(uint256 => bytes32) private _tokenRootMap;
    uint256 private _currentTokenId;

    function mint(bytes32 _root) public {
        _currentTokenId += 1;
        balanceOf[msg.sender] = _currentTokenId;
        ownerOf[_currentTokenId] = msg.sender;
        _setTokenRoot(_currentTokenId, _root);
    }

    function isApprovedForTransfer(
        uint256 _tokenId,
        string memory _code,
        bytes32[] calldata _proof
    ) public view override(IPTT) returns (bool) {
        if (Strings.stringify(_code) <= _lastProcessed[_tokenId]) {
            return false;
        } else {
            bytes32 leaf = keccak256(abi.encodePacked(_code));
            return Merkle.verify(_proof, _tokenRoot(_tokenId), leaf);
        }
    }

    function initializeTransaction(uint256 _tokenId) public payable {
        require(initialized[_tokenId] == address(0));
        offer[_tokenId][msg.sender] = msg.value;
        emit Initialize(ownerOf[_tokenId], msg.sender, _tokenId, msg.value);
    }

    function revertTransaction(uint256 _tokenId) public {
        require(initialized[_tokenId] == address(0));
        uint256 amount = offer[_tokenId][msg.sender];
        delete offer[_tokenId][msg.sender];
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETHER_TRANSFER_FAILED");
        emit Revert(ownerOf[_tokenId], msg.sender, _tokenId, amount);
    }

    function acceptTransaction(
        address _from,
        address _to,
        uint256 _tokenId,
        string memory _code,
        bytes32[] calldata _proof
    ) public {
        require(
            _from == ownerOf[_tokenId] &&
                isApprovedForTransfer(_tokenId, _code, _proof)
        );
        _processLeaf(_tokenId, _code, _proof);
        initialized[_tokenId] = _to;
        emit Accept(ownerOf[_tokenId], _to, _tokenId, offer[_tokenId][_to]);
    }

    function transfer(
        address _from,
        address _to,
        uint256 _tokenId,
        string memory _code,
        bytes32[] calldata _proof
    ) public {
        require(
            _from == ownerOf[_tokenId] &&
                _to == initialized[_tokenId] &&
                isApprovedForTransfer(_tokenId, _code, _proof)
        );
        _processLeaf(_tokenId, _code, _proof);
        unchecked {
            balanceOf[_from] -= 1;
            balanceOf[_to] += 1;
        }
        ownerOf[_tokenId] = _to;
        delete initialized[_tokenId];
        uint256 amount = offer[_tokenId][_to];
        (bool success, ) = payable(_from).call{value: amount}("");
        require(success, "ETHER_TRANSFER_FAILED");
        emit Transfer(_from, _to, _tokenId);
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
        uint128 num = uint128(Strings.stringify(_code));
        _processedMap[_tokenId][leaf] = num;
        _lastProcessed[_tokenId] = num;
    }
}

library Strings {
    function stringify(string memory _string)
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
