// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import "./IPTT.sol";
import "@0xver/solver/library/Merkle.sol";
import "@0xver/solver/interface/IERC165.sol";

/// @title Physically Transferrable Token (PTT) implementation
/// @dev This is a non-optimized implementation
contract PTT is IPTT, IERC165 {
    mapping(uint256 => address) public override(IPTT) ownerOf;
    mapping(uint256 => address) public override(IPTT) transferee;
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
        _tokenRootMap[_currentTokenId] = _root;
        emit Transfer(address(0), msg.sender, _currentTokenId);
    }

    function initializeOffer(address _transferee, uint256 _tokenId)
        public
        payable
        override(IPTT)
    {
        require(transferee[_tokenId] == address(0));
        initializerTokenOffer[_transferee][_tokenId] = msg.value;
        emit InitializeOffer(
            ownerOf[_tokenId],
            _transferee,
            _tokenId,
            msg.value
        );
    }

    function revertOffer(uint256 _tokenId) public override(IPTT) {
        require(transferee[_tokenId] == address(0));
        uint256 amount = initializerTokenOffer[msg.sender][_tokenId];
        delete initializerTokenOffer[msg.sender][_tokenId];
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETHER_TRANSFER_FAILED");
        emit RevertOffer(ownerOf[_tokenId], msg.sender, _tokenId, amount);
    }

    function acceptOffer(
        address _from,
        address _to,
        uint256 _tokenId
    ) public override(IPTT) {
        require(
            transferee[_tokenId] == address(0) && _from == ownerOf[_tokenId]
        );
        transferee[_tokenId] = _to;
        emit AcceptOffer(
            ownerOf[_tokenId],
            _to,
            _tokenId,
            initializerTokenOffer[_to][_tokenId]
        );
    }

    function refundOffer(address _transferee, uint256 _tokenId)
        public
        override(IPTT)
    {
        require(
            transferee[_tokenId] != address(0) &&
                ownerOf[_tokenId] == msg.sender
        );
        delete transferee[_tokenId];
        uint256 amount = initializerTokenOffer[_transferee][_tokenId];
        delete initializerTokenOffer[_transferee][_tokenId];
        (bool success, ) = payable(_transferee).call{value: amount}("");
        require(success, "ETHER_TRANSFER_FAILED");
        emit RefundOffer(msg.sender, _transferee, _tokenId, amount);
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
                _isValidTransferCode(_tokenId, _code, _proof),
            "TRANSFER_FAILED"
        );
        _processLeaf(_tokenId, _code, _proof);
        if (transferee[_tokenId] != address(0)) {
            require(transferee[_tokenId] == _to);
            delete transferee[_tokenId];
            uint256 amount = initializerTokenOffer[_to][_tokenId];
            delete initializerTokenOffer[_to][_tokenId];
            (bool success, ) = payable(_from).call{value: amount}("");
            require(success, "ETHER_TRANSFER_FAILED");
        }
        ownerOf[_tokenId] = _to;
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

    function _numberfy(string memory _code)
        internal
        pure
        returns (uint256 number)
    {
        for (uint256 i = 0; i < bytes(_code).length; i++) {
            if (
                (uint8(bytes(_code)[i]) - 48) < 0 ||
                (uint8(bytes(_code)[i]) - 48) > 9
            ) {
                return 0;
            }
            number +=
                (uint8(bytes(_code)[i]) - 48) *
                10**(bytes(_code).length - i - 1);
        }
    }

    function _processLeaf(
        uint256 _tokenId,
        string memory _code,
        bytes32[] calldata _proof
    ) private {
        bytes32 leaf = keccak256(abi.encodePacked(_code));
        require(
            Merkle.verify(_proof, _tokenRootMap[_tokenId], leaf),
            "INVALID_PROOF"
        );
        _processedMap[_tokenId][leaf] = _numberfy(_code);
        _lastProcessed[_tokenId] = _numberfy(_code);
    }

    function _isValidTransferCode(
        uint256 _tokenId,
        string memory _code,
        bytes32[] calldata _proof
    ) private view returns (bool) {
        if (_numberfy(_code) <= _lastProcessed[_tokenId]) {
            return false;
        }
        bytes32 leaf = keccak256(abi.encodePacked(_code));
        return Merkle.verify(_proof, _tokenRootMap[_tokenId], leaf);
    }
}
