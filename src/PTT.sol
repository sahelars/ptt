// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import "./IPTT.sol";
import "@0xver/solver/library/Merkle.sol";
import "@0xver/solver/interface/IERC165.sol";

/// @title Physically Transferrable Token (PTT) implementation
/// @dev This is a non-optimized implementation
contract PTT is IPTT, IERC165 {
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
